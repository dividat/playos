module type Fun = sig
  type args
  type ret

  val f : args -> ret
end

module type MockFun = sig
  type args
  type ret
  type result = Return of ret | Exception of exn

  val run : args -> ret
  val reset : unit -> unit
  val calls : (args * result) Queue.t
  val calls_clear : unit -> unit
  val was_called : unit -> bool
  val was_called_with : args -> bool
  val update_f : (args -> ret) -> unit
end

module MakeMockFun (F : Fun) :
  MockFun with type args := F.args and type ret := F.ret = struct
  type result = Return of F.ret | Exception of exn

  let calls = Queue.create ()
  let int_f = ref F.f
  let update_f f = int_f := f
  let calls_clear () = Queue.clear calls

  let reset () =
    calls_clear ();
    int_f := F.f

  let run x =
    let out = try Return (!int_f x) with e -> Exception e in
    Queue.add (x, out) calls;
    match out with Return a -> a | Exception e -> raise e

  let was_called () = not (Queue.is_empty calls)

  let was_called_with arg =
    let arg_eq (arg', _) = arg' == arg in
    Queue.fold (fun x y -> x || arg_eq y) false calls
end

let to_fun_mod (type args' ret') (f' : args' -> ret') :
    (module Fun with type args = args' and type ret = ret') =
  (module struct
    type args = args'
    type ret = ret'

    let f = f'
  end)
