# Assert is a unit testing framework for PostgreSQL



```sql
CREATE EXTENSION assert;
```


Equal asserts that two objects are equal.


```sql
select assert.Equal(2+2, 4);
select assert.NotEqual(2+2, 5);
```

Boolean asserts that the specified value is true/false.

```sql
select assert.True((SELECT 2 + 2 = 4));
select assert.False((SELECT 2 + 2 = 5));
```

Null/Not null asserts

```sql
select assert.Null(null);
select assert.NotNull(42);
```

Exception asserts

```sql
select assert.Exception('select t', 'column "t" does not exist');
```

**Example:**

```sql
create or replace function example_auth.TestHash() returns void as $$
    declare
        _hash   char(64);
        _hashes char(64)[] default '{}';
    begin

        FOR i IN 1..1000 LOOP

            _hash = example_auth.hash();

            IF NOT (assert.Equal(char_length(_hash), 64, 'Check hash length') AND assert.False(_hashes @> ARRAY[_hash])) THEN
                EXIT;
            END IF;

            _hashes = array_append(_hashes, _hash);

        END LOOP;

    end;
$$ language plpgsql;

create or replace function example_auth.TestLogin() returns void as $$
    declare
        _login varchar;
        _query text;
    begin

        _query = 'SELECT * FROM example_auth.login(''not'', ''found'')';

        IF assert.Exception(_query, 'NOT_FOUND') THEN

            _query = 'SELECT * FROM example_auth.login(''admin'', ''ip'')';

            IF assert.Exception(_query, 'INVALID_PASSWORD') THEN

                SELECT login INTO _login FROM example_auth.get_auth_user(example_auth.login('admin', 'password'));

                PERFORM assert.Equal('admin_', _login);

            END IF;

        END IF;

    end;
$$ language plpgsql;


insert into assert.tests (test_func) values ('example_auth.TestHash'), ('example_auth.TestLogin');

select * from assert.TestRunner()\x

/*

-[ RECORD 1 ]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
test   | example_auth.TestHash
result | PASS
errors | []
time   | 00:00:00.212931
-[ RECORD 2 ]----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
test   | example_auth.TestLogin
result | FAIL
errors | [{"error": "Not equal: admin_ (expected) != admin (actual)", "context": "PL/pgSQL function assert.equal(anyelement,anyelement,text) line 6 at GET DIAGNOSTICS\nSQL statement \"SELECT assert.Equal('admin_', _login)\"\nPL/pgSQL function example_auth.testlogin() line 17 at PERFORM\nSQL statement \"SELECT example_auth.TestLogin()\"\nPL/pgSQL function assert.runtests(text) line 28 at EXECUTE\nPL/pgSQL function assert.testrunner() line 6 at assignment", "description": ""}]
time   | 00:00:00.004142

*/
```
