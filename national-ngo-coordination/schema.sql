BEGIN;

-- 1. Tables with no dependencies on other tables.
CREATE TABLE association (
    cif VARCHAR(20) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(250) NOT NULL,
    province VARCHAR(100) NOT NULL,
    type VARCHAR(80) NOT NULL,
    has_public_benefit_status BOOLEAN NOT NULL
);
CREATE TABLE association_member (
    dni VARCHAR(20) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    address VARCHAR(250) NOT NULL,
    province VARCHAR(100) NOT NULL
);

-- 2. WORKER and PROJECT depend on ASSOCIATION.
-- Each worker belongs to exactly one association.
-- The triggers below prevent being a member and a worker of the same association.
CREATE TABLE worker (
    dni VARCHAR(20) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    start_date DATE NOT NULL,
    association_cif VARCHAR(20) NOT NULL,

    CONSTRAINT fk_worker_association
        FOREIGN KEY (association_cif)
        REFERENCES association (cif),

    -- DNI is already unique; this key supports ASSIGNMENT's composite FK.
    CONSTRAINT uq_worker_dni_association_cif
        UNIQUE (dni, association_cif)
);
-- A project's number is unique within its owning association.
CREATE TABLE project (
    cif VARCHAR(20) NOT NULL,
    project_number INTEGER NOT NULL,
    country VARCHAR(100) NOT NULL,
    region VARCHAR(150) NOT NULL,
    objective TEXT NOT NULL,
    beneficiary_count INTEGER NOT NULL,
    parent_project_number INTEGER,

    CONSTRAINT pk_project
        PRIMARY KEY (cif, project_number),

    CONSTRAINT fk_project_association
        FOREIGN KEY (cif)
        REFERENCES association (cif),

    -- A NULL parent identifies a top-level project.
    -- The child and its parent must belong to the same association.
    CONSTRAINT fk_project_parent
        FOREIGN KEY (cif, parent_project_number)
        REFERENCES project (cif, project_number)
        DEFERRABLE INITIALLY IMMEDIATE,

    CONSTRAINT ck_project_number
        CHECK (project_number > 0),

    CONSTRAINT ck_project_beneficiary_count
        CHECK (beneficiary_count >= 0),

    -- Pending rule: prevent cycles involving multiple projects. 
    -- This CHECK only prevents a project from being its own parent.
    CONSTRAINT ck_project_no_self_parent
        CHECK (parent_project_number IS NULL OR parent_project_number <> project_number)
);

-- 3. Worker subtypes reuse WORKER's primary key as a foreign key.
-- Pending rule: each worker must be exactly one of SALARIED_EMPLOYEE or VOLUNTEER. 
CREATE TABLE salaried_employee (
    dni VARCHAR(20) PRIMARY KEY,
    salary NUMERIC(12, 2) NOT NULL,
    job_title VARCHAR(100) NOT NULL,
    social_security_contribution NUMERIC(12, 2) NOT NULL,
    income_tax_rate NUMERIC(5, 2) NOT NULL,

    CONSTRAINT fk_salaried_employee_worker
        FOREIGN KEY (dni)
        REFERENCES worker (dni)
        ON DELETE CASCADE,

    CONSTRAINT ck_salaried_employee_salary
        CHECK (salary >= 0 AND salary <> 'NaN'::NUMERIC),

    CONSTRAINT ck_salaried_employee_social_security_contribution
        CHECK (
            social_security_contribution >= 0
            AND social_security_contribution <> 'NaN'::NUMERIC
        ),

    CONSTRAINT ck_salaried_employee_income_tax_rate
        CHECK (income_tax_rate BETWEEN 0 AND 100)
);
CREATE TABLE volunteer (
    dni VARCHAR(20) PRIMARY KEY,
    age SMALLINT NOT NULL,
    profession VARCHAR(100) NOT NULL,
    -- The specification does not define the period covered by these hours.
    committed_hours NUMERIC(8, 2) NOT NULL,

    CONSTRAINT fk_volunteer_worker
        FOREIGN KEY (dni)
        REFERENCES worker (dni)
        ON DELETE CASCADE,

    CONSTRAINT ck_volunteer_age
        CHECK (age >= 0),

    CONSTRAINT ck_volunteer_committed_hours
        CHECK (committed_hours >= 0 AND committed_hours <> 'NaN'::NUMERIC)
);

-- 4. Junction tables for the many-to-many relationships.
-- MEMBERSHIP stores the join date and monthly fee for each membership.
-- Pending rules: each association must have at least one member, and each member must belong to at least one association.
CREATE TABLE membership (
    cif VARCHAR(20) NOT NULL,
    dni VARCHAR(20) NOT NULL,
    join_date DATE NOT NULL,
    monthly_fee NUMERIC(12, 2) NOT NULL,

    CONSTRAINT pk_membership
        PRIMARY KEY (cif, dni),

    CONSTRAINT fk_membership_association
        FOREIGN KEY (cif)
        REFERENCES association (cif),

    CONSTRAINT fk_membership_association_member
        FOREIGN KEY (dni)
        REFERENCES association_member (dni),

    CONSTRAINT ck_membership_monthly_fee
        CHECK (monthly_fee >= 0 AND monthly_fee <> 'NaN'::NUMERIC)
);
-- ASSIGNMENT links workers to projects.
CREATE TABLE assignment (
    dni VARCHAR(20) NOT NULL,
    cif VARCHAR(20) NOT NULL,
    project_number INTEGER NOT NULL,

    CONSTRAINT pk_assignment
        PRIMARY KEY (dni, cif, project_number),

    -- Both foreign keys share the same CIF, so the worker and project must belong to the same association.
    CONSTRAINT fk_assignment_worker
        FOREIGN KEY (dni, cif)
        REFERENCES worker (dni, association_cif),

    CONSTRAINT fk_assignment_project
        FOREIGN KEY (cif, project_number)
        REFERENCES project (cif, project_number)
);

-- 5. Supporting indexes for foreign keys not covered by a PK/UNIQUE index prefix.
-- These indexes support lookups and foreign key checks.
CREATE INDEX idx_membership_association_member
    ON membership (dni);

CREATE INDEX idx_worker_association
    ON worker (association_cif);

CREATE INDEX idx_assignment_project
    ON assignment (cif, project_number);

CREATE INDEX idx_project_parent
    ON project (cif, parent_project_number)
    WHERE parent_project_number IS NOT NULL;

-- 6. A person cannot be both a member and a worker of the same association.
-- Both tables call the same function after inserting or changing a DNI/CIF.
CREATE FUNCTION check_member_worker_exclusion()
RETURNS TRIGGER
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
    target_cif VARCHAR(20);
BEGIN
    IF TG_TABLE_NAME = 'worker' THEN
        target_cif := NEW.association_cif;
    ELSE
        target_cif := NEW.cif;
    END IF;

    -- This intentional write preserves the name and serializes role changes
    -- within the association until COMMIT/ROLLBACK. A new row version also
    -- makes stale REPEATABLE READ/SERIALIZABLE transactions fail safely.
    -- A SELECT FOR UPDATE alone would not invalidate those older snapshots.
    UPDATE association AS a
    SET name = a.name
    WHERE a.cif = target_cif;

    IF EXISTS (
        SELECT 1
        FROM membership AS m
        JOIN worker AS w
            ON w.dni = m.dni
            AND w.association_cif = m.cif
        WHERE m.dni = NEW.dni
            AND m.cif = target_cif
    ) THEN
        RAISE EXCEPTION
            'Person with DNI % cannot be both a member and a worker of association %.',
            NEW.dni, target_cif
            USING ERRCODE = '23514',
                  CONSTRAINT = 'ck_member_worker_exclusion';
    END IF;

    -- AFTER triggers ignore the return value.
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_membership_no_worker
    AFTER INSERT OR UPDATE OF dni, cif ON membership
    FOR EACH ROW
    EXECUTE FUNCTION check_member_worker_exclusion();

CREATE TRIGGER trg_worker_no_membership
    AFTER INSERT OR UPDATE OF dni, association_cif ON worker
    FOR EACH ROW
    EXECUTE FUNCTION check_member_worker_exclusion();

-- 7. Derived annual fees, calculated from the current monthly fee.
CREATE VIEW annual_fees AS
SELECT
    cif,
    dni,
    join_date,
    monthly_fee,
    monthly_fee * 12 AS annual_fee
FROM membership;

COMMIT;
