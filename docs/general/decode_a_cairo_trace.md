# How to decode a Cairo trace

When there is an error in a cairo program, the VM throws something like:

```shell
Cairo traceback (most recent call last):
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:18081)
Unknown location (pc=0:17991)
Unknown location (pc=0:17966)
Unknown location (pc=0:16124)
Unknown location (pc=0:16431)
Unknown location (pc=0:16398)
```

There is a simple util function in the Starkware python library that decodes
this cryptic message to map location in the original cairo program.

## Quick start

- Make sure you have installed the proper libraries locally (cairo-lang, etc.),
  i.e. the project's python dependencies

- Make sure to compile Kakarot with `debug_info`

  - by default in the `compile_kakarot.py` script, the `--no_debug_info` is
    applied when the target network is not a devnet (e.g katana)
  - to use the tooling as is, just run
    `STARKNET_NETWORK=starknet-devnet python scripts/compile_kakarot.py` or
    `make build` if you set katana as your `STARKNET_NETWORK` in `.env`

- Then, use this simple snippet as a standalone Python file

  ```python
  # %% Imports
  import json

  from scripts.utils.starknet import get_artifact
  from starkware.cairo.lang.compiler.program import Program
  from starkware.cairo.lang.vm.reconstruct_traceback import reconstruct_traceback

  kakarot_program = Program.load(
      data=json.loads(get_artifact("kakarot").read_text())["program"]
  )

  # Just copy/paste the whole stack, just shorten in the snippet for clarity
  error_message = """
  Cairo traceback (most recent call last):
  Unknown location (pc=0:18081)
  Unknown location (pc=0:18081)
  """
  print(reconstruct_traceback(kakarot_program, error_message))
  ```

And tada! You should now be able to understand the reason your cairo program
failed with more clarity.
