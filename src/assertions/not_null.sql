create or replace function assert.NotNull(_object anyelement, _description text default '') returns boolean as $$
    begin
        return true;
    end;
$$ language plpgsql;

create or replace function assert.NotNull(_object text, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _object IS NULL THEN
            return assert.Fail('Expected value not to be null.', _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;
