BEGIN;

-- 1. Tables with no dependencies on other tables.
CREATE TABLE agency (
    agency_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);
CREATE TABLE garage (
    garage_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);
CREATE TABLE customer (
    customer_code INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dni VARCHAR(20) NOT NULL,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(250) NOT NULL,
    phone_number VARCHAR(30) NOT NULL,
    guarantor_code INTEGER,

    -- A customer may be guaranteed by another customer.
    CONSTRAINT fk_customer_guarantor
        FOREIGN KEY (guarantor_code)
        REFERENCES customer (customer_code)
        ON DELETE RESTRICT,

    CONSTRAINT ck_customer_guarantor_different
        CHECK (guarantor_code IS NULL OR guarantor_code <> customer_code)
);

-- 2. CAR depends on GARAGE; RESERVATION depends on CUSTOMER and AGENCY.
CREATE TABLE car (
    license_plate VARCHAR(20) PRIMARY KEY,
    model VARCHAR(100) NOT NULL,
    make VARCHAR(100) NOT NULL,
    color VARCHAR(50) NOT NULL,
    garage_id INTEGER NOT NULL,

    CONSTRAINT fk_car_garage
        FOREIGN KEY (garage_id)
        REFERENCES garage (garage_id)
        ON DELETE RESTRICT
);
CREATE TABLE reservation (
    reservation_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_price DECIMAL(12,2) NOT NULL,
    -- TRUE when all cars in the reservation have been returned.
    returned BOOLEAN NOT NULL DEFAULT FALSE,
    customer_code INTEGER NOT NULL,
    agency_id INTEGER NOT NULL,

    CONSTRAINT fk_reservation_customer
        FOREIGN KEY (customer_code)
        REFERENCES customer (customer_code)
        ON DELETE RESTRICT,

    CONSTRAINT fk_reservation_agency
        FOREIGN KEY (agency_id)
        REFERENCES agency (agency_id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_reservation_dates
        CHECK (end_date >= start_date),

    CONSTRAINT ck_reservation_total_price
        CHECK (total_price >= 0)
);

-- 3. Junction table for the many-to-many relationship between reservations and cars.
-- Each row stores the gasoline level and rental price of a car for a reservation.
-- The application must ensure that each reservation contains at least one car.
CREATE TABLE reservation_details (
    reservation_id INTEGER NOT NULL,
    license_plate VARCHAR(20) NOT NULL,
    gasoline_liters DECIMAL(6,2) NOT NULL,
    rental_price DECIMAL(12,2) NOT NULL,

    CONSTRAINT pk_reservation_details
        PRIMARY KEY (reservation_id, license_plate),

    CONSTRAINT fk_reservation_details_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservation (reservation_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_reservation_details_car
        FOREIGN KEY (license_plate)
        REFERENCES car (license_plate)
        ON DELETE RESTRICT,

    CONSTRAINT ck_reservation_details_rental_price
        CHECK (rental_price >= 0),

    CONSTRAINT ck_reservation_details_gasoline_liters
        CHECK (gasoline_liters >= 0)
);

-- 4. A car's assigned garage cannot change after the car is registered.
-- OLD contains the existing row; NEW contains the proposed updated row.
CREATE FUNCTION prevent_garage_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.garage_id IS DISTINCT FROM OLD.garage_id THEN
        RAISE EXCEPTION 'The garage assigned to a car cannot change';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER car_garage_fixed
BEFORE UPDATE ON car
FOR EACH ROW
EXECUTE FUNCTION prevent_garage_change();

COMMIT;
