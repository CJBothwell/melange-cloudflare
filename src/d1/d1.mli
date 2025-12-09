(** Cloudflare D1 Database Bindings.

    D1 is Cloudflare's serverless SQL database built on SQLite. This module
    provides type-safe bindings for executing SQL queries, managing transactions,
    and working with query results.

    D1 databases are accessed through environment bindings and provide a
    familiar SQL interface with async/await support.

    @author Melange Cloudflare Bindings
    @version 1.0.0
*)

(** {1 D1 Database} *)

(** The D1Database type represents a connection to a D1 database.

    D1 databases are bound to your Worker through environment variables.
    Each database binding provides methods to execute queries and manage
    transactions.
*)
module rec Database : sig
  (** The type representing a D1 database instance. *)
  type t

  (** {2 Query Execution} *)

  (** [prepare db sql] creates a prepared statement.

      Prepared statements allow you to safely execute SQL with parameters,
      preventing SQL injection attacks. Parameters are bound using [?] placeholders
      in the SQL string.

      @param db The database instance.
      @param sql The SQL query string with optional [?] parameter placeholders.
      @return A prepared statement ready to be executed.

      Example: [prepare db "SELECT * FROM users WHERE id = ?"]
  *)
  val prepare : t -> string -> Statement.t

  (** [exec db sql] executes raw SQL without returning results.

      This is useful for DDL operations (CREATE TABLE, ALTER TABLE, etc.) or
      multiple statements. The SQL can contain multiple statements separated
      by semicolons. This method does not support parameter binding.

      @param db The database instance.
      @param sql The SQL string (may contain multiple statements).
      @return A Promise that resolves to the execution result.

      Example: [exec db "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"]
  *)
  val exec : t -> string -> ExecResult.t Js.Promise.t

  (** [dump db] exports the entire database as SQL statements.

      @param db The database instance.
      @return A Promise that resolves to a string containing SQL statements.
  *)
  val dump : t -> string Js.Promise.t

  (** [batch db statements] executes multiple statements in a transaction.

      All statements are executed atomically - if any statement fails, all
      changes are rolled back. This is more efficient than executing statements
      individually as it requires only one round trip.

      @param db The database instance.
      @param statements An array of prepared statements to execute.
      @return A Promise that resolves to an array of results, one per statement.

      Example:
      {[
        let stmt1 = prepare db "INSERT INTO users (name) VALUES (?)" in
        let stmt2 = prepare db "UPDATE stats SET count = count + 1" in
        batch db [|stmt1; stmt2|]
      ]}
  *)
  val batch : t -> Statement.t array -> QueryResult.t array Js.Promise.t
end

(** {1 Prepared Statements} *)

(** A prepared statement represents a parameterized SQL query.

    Statements can be bound with parameters and executed multiple times
    with different parameter values. This is both more secure (prevents
    SQL injection) and more efficient than string concatenation.
*)
and Statement : sig
  (** The type representing a prepared statement. *)
  type t

  (** {2 Parameter Binding} *)

  (** [bind stmt params] binds parameters to the statement.

      Parameters are bound positionally to [?] placeholders in the SQL.
      The number of parameters must match the number of placeholders.

      @param stmt The prepared statement.
      @param params An array of parameter values (strings, numbers, nulls, etc.).
      @return The statement with bound parameters.

      Example:
      {[
        let stmt = prepare db "SELECT * FROM users WHERE age > ? AND city = ?" in
        let stmt' = bind stmt [|Js.Json.number 18.0; Js.Json.string "NYC"|] in
        first stmt'
      ]}
  *)
  val bind : t -> Js.Json.t array -> t

  (** {2 Query Execution} *)

  (** [all stmt] executes the statement and returns all matching rows.

      This is the most common way to execute SELECT queries. It returns
      all rows that match the query along with metadata about the execution.

      @param stmt The prepared statement (with parameters bound if needed).
      @return A Promise that resolves to the query results.

      Example:
      {[
        let stmt = prepare db "SELECT * FROM users" in
        Js.Promise.(
          all stmt
          |> then_ (fun result ->
              let rows = QueryResult.results result in
              Array.iter (fun row ->
                Js.log row
              ) rows;
              resolve ()
          )
        )
      ]}
  *)
  val all : t -> QueryResult.t Js.Promise.t

  (** [first stmt] executes the statement and returns only the first row.

      This is useful when you expect a single result (e.g., finding a user by ID)
      or when you only care about the first match. Returns [None] if no rows match.

      @param stmt The prepared statement.
      @return A Promise that resolves to [Some row] or [None].

      Example:
      {[
        let stmt = prepare db "SELECT * FROM users WHERE id = ?" |> bind [|id|] in
        Js.Promise.(
          first stmt
          |> then_ (fun user ->
              match user with
              | Some u -> (* process user *)
              | None -> (* user not found *)
              resolve ()
          )
        )
      ]}
  *)
  val first : t -> Js.Json.t option Js.Promise.t

  (** [first_column stmt] executes the statement and returns the first column.

      This is optimized for queries that return a single column value, such as
      aggregates (COUNT, SUM, etc.) or when fetching a single field.

      @param stmt The prepared statement.
      @return A Promise that resolves to [Some value] or [None].

      Example:
      {[
        let stmt = prepare db "SELECT COUNT(*) FROM users" in
        Js.Promise.(
          first_column stmt
          |> then_ (fun count ->
              match count with
              | Some (Js.Json.Number n) -> Printf.printf "User count: %f\n" n
              | _ -> ();
              resolve ()
          )
        )
      ]}
  *)
  val first_column : t -> Js.Json.t option Js.Promise.t

  (** [run stmt] executes the statement without returning rows.

      This is used for INSERT, UPDATE, DELETE, and other statements where
      you care about the execution metadata (rows changed, last inserted ID)
      but not the row data itself.

      @param stmt The prepared statement.
      @return A Promise that resolves to the execution result.

      Example:
      {[
        let stmt = prepare db "DELETE FROM users WHERE age < ?" |> bind [|age|] in
        Js.Promise.(
          run stmt
          |> then_ (fun result ->
              let changed = QueryResult.changes result in
              Printf.printf "Deleted %d rows\n" changed;
              resolve ()
          )
        )
      ]}
  *)
  val run : t -> QueryResult.t Js.Promise.t

  (** [raw stmt] executes the statement and returns rows as arrays.

      Instead of returning rows as objects with named fields, this returns
      each row as an array of values in column order. This can be more
      efficient for large result sets.

      @param stmt The prepared statement.
      @return A Promise that resolves to an array of row arrays.

      Example:
      {[
        let stmt = prepare db "SELECT id, name FROM users" in
        Js.Promise.(
          raw stmt
          |> then_ (fun rows ->
              (* Each row is [id, name] *)
              Array.iter (fun row ->
                match row with
                | [|id; name|] -> Js.log2 id name
                | _ -> ()
              ) rows;
              resolve ()
          )
        )
      ]}
  *)
  val raw : t -> Js.Json.t array array Js.Promise.t
end

(** {1 Query Results} *)

(** Query results contain the rows returned by a query along with metadata
    about the execution (success status, rows changed, etc.).
*)
and QueryResult : sig
  (** The type representing query results. *)
  type t

  (** [results qr] gets the array of result rows.

      Each row is returned as a JSON object with fields corresponding to
      the selected columns.

      @param qr The query result.
      @return An array of row objects.
  *)
  val results : t -> Js.Json.t array

  (** [success qr] checks if the query executed successfully.

      @param qr The query result.
      @return [true] if successful, [false] otherwise.
  *)
  val success : t -> bool

  (** [meta qr] gets execution metadata.

      @param qr The query result.
      @return Metadata about the query execution.
  *)
  val meta : t -> ResultMeta.t

  (** [error qr] gets the error message if the query failed.

      @param qr The query result.
      @return [Some error_message] if the query failed, [None] if successful.
  *)
  val error : t -> string option

  (** [changes qr] gets the number of rows changed.

      For INSERT, UPDATE, or DELETE statements, this returns the number
      of rows affected.

      @param qr The query result.
      @return The number of rows changed.
  *)
  val changes : t -> int

  (** [duration qr] gets the query execution time in milliseconds.

      @param qr The query result.
      @return The execution duration.
  *)
  val duration : t -> float

  (** [lastRowId qr] gets the ROWID of the last inserted row.

      For INSERT statements, this returns the ROWID of the newly inserted row.
      For tables with an INTEGER PRIMARY KEY, this is the same as the primary key.

      @param qr The query result.
      @return [Some rowid] if an insert occurred, [None] otherwise.
  *)
  val lastRowId : t -> int option
end

(** Metadata about query execution. *)
and ResultMeta : sig
  (** The type representing result metadata. *)
  type t

  (** [duration meta] gets the execution duration in milliseconds.

      @param meta The result metadata.
      @return The execution time.
  *)
  val duration : t -> float

  (** [changes meta] gets the number of rows changed.

      @param meta The result metadata.
      @return The number of rows affected.
  *)
  val changes : t -> int

  (** [lastRowId meta] gets the last inserted ROWID.

      @param meta The result metadata.
      @return [Some rowid] if applicable, [None] otherwise.
  *)
  val lastRowId : t -> int option

  (** [changedDb meta] checks if the database was modified.

      @param meta The result metadata.
      @return [true] if the query modified the database, [false] otherwise.
  *)
  val changedDb : t -> bool

  (** [sizeAfter meta] gets the database size after the query in bytes.

      @param meta The result metadata.
      @return [Some size] if available, [None] otherwise.
  *)
  val sizeAfter : t -> int option

  (** [rowsRead meta] gets the number of rows read during execution.

      This can be larger than the number of rows returned if the query
      involved filtering or aggregation.

      @param meta The result metadata.
      @return [Some count] if available, [None] otherwise.
  *)
  val rowsRead : t -> int option

  (** [rowsWritten meta] gets the number of rows written.

      @param meta The result metadata.
      @return [Some count] if available, [None] otherwise.
  *)
  val rowsWritten : t -> int option
end

(** {1 Exec Results} *)

(** Results from executing raw SQL with [exec].

    The exec method can run multiple statements in one call, so the result
    includes information about each statement's execution.
*)
and ExecResult : sig
  (** The type representing exec results. *)
  type t

  (** [count res] gets the number of statements executed.

      @param res The exec result.
      @return The number of SQL statements that were executed.
  *)
  val count : t -> int

  (** [duration res] gets the total execution time in milliseconds.

      @param res The exec result.
      @return The total duration for all statements.
  *)
  val duration : t -> float
end

(** {1 Type Helpers} *)

(** Helper functions for working with D1 result rows.

    D1 returns rows as JSON objects. These helpers provide type-safe
    ways to extract values from row objects.
*)
module Row : sig
  (** [get_string row field] extracts a string field from a row.

      @param row The row object.
      @param field The field name.
      @return [Some value] if the field exists and is a string, [None] otherwise.
  *)
  val get_string : Js.Json.t -> string -> string option

  (** [get_int row field] extracts an integer field from a row.

      @param row The row object.
      @param field The field name.
      @return [Some value] if the field exists and is a number, [None] otherwise.
  *)
  val get_int : Js.Json.t -> string -> int option

  (** [get_float row field] extracts a float field from a row.

      @param row The row object.
      @param field The field name.
      @return [Some value] if the field exists and is a number, [None] otherwise.
  *)
  val get_float : Js.Json.t -> string -> float option

  (** [get_bool row field] extracts a boolean field from a row.

      @param row The row object.
      @param field The field name.
      @return [Some value] if the field exists and is a boolean, [None] otherwise.
  *)
  val get_bool : Js.Json.t -> string -> bool option

  (** [get_nullable row field] checks if a field is NULL.

      @param row The row object.
      @param field The field name.
      @return [true] if the field is NULL, [false] otherwise.
  *)
  val get_nullable : Js.Json.t -> string -> bool

  (** [get_json row field] extracts a JSON field from a row.

      For columns containing JSON data, this returns the parsed JSON value.

      @param row The row object.
      @param field The field name.
      @return [Some json] if the field exists, [None] otherwise.
  *)
  val get_json : Js.Json.t -> string -> Js.Json.t option

  (** [to_dict row] converts a row to a string dictionary.

      @param row The row object.
      @return A Js.Dict.t of field names to JSON values.
  *)
  val to_dict : Js.Json.t -> Js.Json.t Js.Dict.t
end

(** {1 Error Handling} *)

(** D1 error types. *)
module Error : sig
  (** D1 error categories. *)
  type error_type =
    | SqlError  (** SQL syntax or execution error *)
    | ConstraintError  (** Constraint violation (unique, foreign key, etc.) *)
    | DatabaseError  (** Internal database error *)
    | NetworkError  (** Network or connection error *)
    | UnknownError  (** Unknown error *)

  (** The type representing a D1 error. *)
  type t = {
    error_type : error_type;  (** The category of error *)
    message : string;  (** The error message *)
    code : string option;  (** The error code if available *)
  }

  (** [message err] gets the error message.

      @param err The error.
      @return The error message string.
  *)
  val message : t -> string

  (** [error_type err] gets the error type.

      @param err The error.
      @return The error category.
  *)
  val error_type : t -> error_type

  (** [code err] gets the error code.

      @param err The error.
      @return [Some code] if available, [None] otherwise.
  *)
  val code : t -> string option

  (** [to_string err] converts the error to a string.

      @param err The error.
      @return A string representation of the error.
  *)
  val to_string : t -> string
end

(** {1 Accessing D1 from Environment} *)

(** [from_env env binding_name] retrieves a D1 database from environment bindings.

    D1 databases are configured in your wrangler.toml and bound to your Worker
    through the environment. This function retrieves the database by its binding name.

    @param env The Worker environment object.
    @param binding_name The name of the D1 binding (as configured in wrangler.toml).
    @return [Some database] if the binding exists, [None] otherwise.

    Example:
    {[
      (* In wrangler.toml:
         [[d1_databases]]
         binding = "DB"
         database_name = "my-database"
         database_id = "..." *)

      let fetch request env ctx =
        match from_env env "DB" with
        | Some db ->
            let stmt = Database.prepare db "SELECT * FROM users" in
            Js.Promise.(
              Statement.all stmt
              |> then_ (fun result ->
                  (* Process result *)
                  resolve (Response.make_json (Js.Json.string "Success") None)
              )
            )
        | None ->
            Response.make_json
              (Js.Json.string "Database not configured")
              (Some { status = Some 500; statusText = None; headers = None; cf = None })
            |> Js.Promise.resolve
    ]}
*)
val from_env : 'env -> string -> Database.t option
