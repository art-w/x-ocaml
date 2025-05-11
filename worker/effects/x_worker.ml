module Effect = struct
  include Stdlib.Effect (* force jsoo to include Stdlib__Effect *)
end

let () = X_worker.run ()
