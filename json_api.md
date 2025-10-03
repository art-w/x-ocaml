
## OCaml Worker JSON API Documentation

This document specifies the JSON API for communicating with the `x-ocaml` Web Worker. All messages are JSON arrays where the first element is a string "tag" that identifies the type of request.

### 1. `Setup`

Initializes the OCaml toplevel environment within the worker. This should be the first message sent after the worker is created.

-   **JSON Structure**:
    ```json
    ["Setup"]
    ```
-   **Fields**: None.
-   **Example**:
    ```json
    ["Setup"]
    ```

---

### 2. `Eval`

Requests the execution of a block of OCaml code. The worker will send back one or more `Top_response_at` messages for intermediate outputs and a final `Top_response` message when execution is complete.

-   **JSON Structure**:
    ```json
    ["Eval", <id>, <line_number>, "<code>"]
    ```
-   **Fields**:
    -   `id` (integer): A unique ID for this request, which will be included in all corresponding responses.
    -   `line_number` (integer): The starting line number for the code block, used for accurate error reporting.
    -   `code` (string): The OCaml source code to execute.
-   **Example**:
    ```json
    ["Eval", 101, 1, "let add x y = x + y;;\nadd 2 3;;"]
    ```

---

### 3. `Format`

Requests that a block of OCaml code be formatted using `ocamlformat`. The worker will respond with a `Formatted_source` message containing the formatted code.

-   **JSON Structure**:
    ```json
    ["Format", <id>, "<code>"]
    ```
-   **Fields**:
    -   `id` (integer): A unique ID for this request.
    -   `code` (string): The unformatted OCaml source code.
-   **Example**:
    ```json
    ["Format", 102, "let x=1 let y=2"]
    ```

---

### 4. `Format_config`

Configures the `ocamlformat` instance within the worker. This should be sent before any `Format` requests to apply custom formatting rules.

-   **JSON Structure**:
    ```json
    ["Format_config", "<config_string>"]
    ```
-   **Fields**:
    -   `config_string` (string): A string containing `ocamlformat` configuration options, separated by newlines (e.g., `"profile=conventional\nparse-docstrings=true"`). Can also be the string `"disable"` to turn off formatting.
-   **Example**:
    ```json
    ["Format_config", "profile=janestreet\nlet-and-in-separate-in-if-then-else=true"]
    ```

---

### 5. `Merlin`

Provides access to Merlin's language server features. This is a wrapper for several sub-actions.

-   **JSON Structure**:
    ```json
    ["Merlin", <id>, <merlin_action>]
    ```
-   **Fields**:
    -   `id` (integer): A unique ID for this Merlin request.
    -   `merlin_action` (JSON Array): A nested array specifying the Merlin command to execute.

#### Merlin Sub-Actions:

##### a) `Complete_prefix`

Requests code completions at a specific cursor position.

-   **Structure**: `["Complete_prefix", "<code>", ["Offset", <cursor_pos>]]`
-   **Fields**:
    -   `code` (string): The source code of the current cell.
    -   `cursor_pos` (integer): The character offset of the cursor from the beginning of the code string.
-   **Example** (requesting completions for `List.m`):
    ```json
    ["Merlin", 201, ["Complete_prefix", "List.m", ["Offset", 6]]]
    ```

##### b) `Type_enclosing`

Requests the type of the expression at the cursor position. This is used for tooltips (inspections).

-   **Structure**: `["Type_enclosing", "<code>", ["Offset", <cursor_pos>]]`
-   **Fields**:
    -   `code` (string): The source code of the current cell.
    -   `cursor_pos` (integer): The character offset of the cursor.
-   **Example** (inspecting the type of `x`):
    ```json
    ["Merlin", 202, ["Type_enclosing", "let x = 42 in x + 1", ["Offset", 15]]]
    ```

##### c) `All_errors`

Requests a list of all syntax and type errors within a block of code.

-   **Structure**: `["All_errors", "<code>"]`
-   **Fields**:
    -   `code` (string): The source code to analyze.
-   **Example**:
    ```json
    ["Merlin", 203, ["All_errors", "let x: int = \"hello\""]]
    ```

##### d) `Add_cmis`

Loads compiled module interfaces (`.cmi` files) into Merlin's environment, enabling it to provide completions and type information for external libraries.

-   **Structure**: `["Add_cmis", { "static_cmis": [...], "dynamic_cmis": ... }]`
-   **Fields**:
    -   `static_cmis` (array of objects): A list of CMI files to load directly. Each object has:
        -   `sc_name` (string): The capitalized module name (e.g., "Str").
        -   `sc_content` (string): The raw binary content of the `.cmi` file.
    -   `dynamic_cmis` (object or `null`): Configuration for fetching CMIs on demand from a URL. The object has:
        -   `dcs_url` (string): The base URL where CMI files are hosted.
        -   `dcs_toplevel_modules` (array of strings): A list of modules to pre-load.
        -   `dcs_file_prefixes` (array of strings): Prefixes for modules that can be dynamically loaded (e.g., `"stdlib__"`).
-   **Example**:
    ```json
    [
      "Merlin",
      204,
      [
        "Add_cmis",
        {
          "static_cmis": [
            {
              "sc_name": "My_module",
              "sc_content": "<raw-binary-content-of-my_module.cmi>"
            }
          ],
          "dynamic_cmis": {
            "dcs_url": "/stdlib/",
            "dcs_toplevel_modules": ["Stdlib", "Str"],
            "dcs_file_prefixes": ["stdlib__"]
          }
        }
      ]
    ]
    