create or replace function assert.Null(_object anyelement, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _object IS NOT NULL THEN
            return assert.Fail(format('Expected null, but got: %s', _object), _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;


create or replace function assert.Null(_object text, _description text default '') returns boolean as $$
    declare
        _context text;
    begin

        GET DIAGNOSTICS _context = PG_CONTEXT;

        IF _object IS NOT NULL THEN
            return assert.Fail(format('Expected null, but got: %s', _object), _description, _context);
        END if;

        return true;
    end;
$$ language plpgsql;
