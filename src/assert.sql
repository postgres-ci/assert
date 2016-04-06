drop schema assert cascade;

create schema assert;

create sequence assert.running_numbers;

create table assert.tests (
    test_id     serial  primary key,
    namespace   name    not null,
    procedure   name    not null check(procedure like 'test\_%'),
    is_running  boolean not null default false,
    created_at  timestamptz not null default current_timestamp
);

create unique index uidx_assert_test_func       on assert.tests (lower(namespace || '.' || procedure));
create unique index uidx_assert_test_is_running on assert.tests (is_running) where is_running = true;

create type assert.error as (
    message  text,
    comment  text,
    context  text
);

create unlogged table assert.errors(
    test_id  int          not null references assert.tests(test_id),
    run_num  bigint       not null default currval('assert.running_numbers'),
    error    assert.error not null
);

create table assert.results(
    test_id     int            not null references assert.tests(test_id),
    run_num     bigint         not null default currval('assert.running_numbers'),
    errors      assert.error[] not null default '{}',
    started_at  timestamptz    not null,
    finished_at timestamptz,
    primary key (run_num, test_id)
);
