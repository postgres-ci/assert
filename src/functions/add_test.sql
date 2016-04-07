create or replace function assert.add_test(_namespace name, _procedure name) returns void as $$
    begin 
        BEGIN
            INSERT INTO assert.tests (namespace, procedure) VALUES (_namespace, _procedure);
        EXCEPTION WHEN UNIQUE_VIOLATION THEN
            RAISE EXCEPTION 'Test "%" already exists', quote_ident(_namespace) || '.' || quote_ident(_procedure);
        END; 
    end;
$$ language plpgsql security definer;