Install Postgres-CI unit testing framework 

```
psql -U user -d database < path/to/framework/assert.sql
```

Init your PL/pgSQL app

```
psql -U user -d database < example.sql
```

Write and init your tests 

```
psql -U user -d database < example_test.sql
```

Register your tests in Postgres-CI database

```sql
select assert.add_test('example', 'test_create_user');
select assert.add_test('example', 'test_constraint');
select assert.add_test('example', 'test_roll_back_a_transaction_for_each_test');
```

Run your tests
```sql
select 
    namespace || '.' || procedure as func,
    case 
        when array_length(errors, 1) is null 
        then 'pass'
        else 'fail' 
    end 
    as result,
    to_json(errors) as errors,
    finished_at - started_at as duration
from  assert.test_runner();
```