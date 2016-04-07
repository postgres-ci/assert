create schema example;

create table example.users(
    user_id   serial primary key,
    user_name varchar not null
);

create or replace function example.create_user(_user_name varchar, out id int) returns int as $$
    begin 

        INSERT INTO example.users (user_name) VALUES (_user_name) RETURNING user_id INTO id;
    end;
$$ language plpgsql;

create or replace function example.uncovered() returns void as $$
$$ language sql;
