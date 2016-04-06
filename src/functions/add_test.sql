create or replace function assert.add_test(_namespace name, _procedure name) returns void as $$
    begin 
        INSERT INTO assert.tests (namespace, procedure) VALUES (_namespace, _procedure);
    end;
$$ language plpgsql security definer;