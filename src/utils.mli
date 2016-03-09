open Core.Std
open Async.Std


(* This seems pretty silly but having the [Port.Table.t] type makes the code more
   readable *)
module Port : sig
  type t = int [@@deriving bin_io]
  include Hashable.S with type t := int
end

(* The internal connection state we keep with every connection to a worker.

   [conn_state] is the user supplied connection state (well there is really a [Set_once.t]
   in there as well)

   [worker_state] is the worker state associated with the given worker. A reference is
   stored here to gracefully handle the cleanup needed when [close_server] is called when
   there are still open connections.

   [server] is the host and port of the worker server that this connection is to. This is
   needed because there can be multiple instances of a given worker server in a single
   process.

   The [Rpc.Connection.t] is the underlying connection that has this state *)
module Internal_connection_state : sig
  type ('worker_state, 'conn_state) t1 =
    { worker_state : 'worker_state
    ; conn_state   : 'conn_state
    ; server       : Port.t }

  type ('worker_state, 'conn_state) t =
    Rpc.Connection.t * ('worker_state, 'conn_state) t1 Set_once.t
end

(* Like [Monitor.try_with], but raise any additional exceptions (raised after [f ()] has
   been determined) to the specified monitor. *)
val try_within
  :  monitor:Monitor.t
  -> (unit -> 'a Deferred.t)
  -> 'a Or_error.t Deferred.t

(* Any exceptions that are raised before [f ()] is determined will be raised to the
   current monitor. Exceptions raised after [f ()] is determined will be raised to the
   passed in monitor *)
val try_within_exn
  :  monitor:Monitor.t
  -> (unit -> 'a Deferred.t)
  -> 'a Deferred.t

(* Get the location of the currently running binary *)
val our_binary : unit -> string Deferred.t

(* Get an md5 hash of the currently running binary *)
val our_md5 : unit -> string Or_error.t Deferred.t

(* Determine in what context the current executable is running *)
val whoami : unit -> [ `Worker of string | `Master ]

(* Clear any environment variables that this library has set *)
val clear_env : unit -> unit

(* Create an environment for a spawned worker to run in *)
val create_worker_env
  :  extra:(string * string) list
  -> id:string
  -> (string * string) list Or_error.t

val to_daemon_fd_redirection
  :  [ `Dev_null | `File_append of string | `File_truncate of string ]
  -> Daemon.Fd_redirection.t
