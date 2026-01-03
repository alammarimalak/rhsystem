CREATE DATABASE systemrh;
USE systemrh;

-- ============================
-- HR USERS TABLE
-- ============================
CREATE TABLE hr_users (
    hr_id INT AUTO_INCREMENT PRIMARY KEY,
    cin VARCHAR(10) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20) UNIQUE,
    status ENUM('Active','Inactive') DEFAULT 'Active',
    last_login DATETIME,
    profile_picture VARCHAR(255)
);

-- ============================
-- DEPARTMENTS TABLE
-- ============================
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100)
);

-- ============================
-- PEOPLE TABLE (Employees, Interns, Candidates)
-- ============================
CREATE TABLE people (
    person_id INT AUTO_INCREMENT PRIMARY KEY,
    cin VARCHAR(10) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    address VARCHAR(255),
    city VARCHAR(50),
    country VARCHAR(50),
    person_type ENUM('Employe','Stagiaire','Candidat') NOT NULL,
    job_title VARCHAR(50),
    uni_major VARCHAR(50),
    uni_level ENUM('Technicien Specialise', 'Licence', 'Master', 'Doctorat', 'Etudiant'),
    uni_name VARCHAR(255),
    department_id INT,
    hire_date DATE,
    status ENUM('Active','Inactive','En attente') DEFAULT 'En attente',
    salary DECIMAL(10,2),
    cv_file VARCHAR(255),
    birth_date DATE,
    FOREIGN KEY (department_id) 
        REFERENCES departments(department_id)
        ON DELETE SET NULL
);

-- ============================
-- FIRED EMPLOYEES TABLE
-- ============================
CREATE TABLE fired_employees (
    fired_id INT AUTO_INCREMENT PRIMARY KEY,
    person_id INT NOT NULL,
    fired_date DATE NOT NULL,
    reason VARCHAR(255),
    FOREIGN KEY (person_id) 
        REFERENCES people(person_id)
        ON DELETE CASCADE
);

-- ============================
-- RETIRED EMPLOYEES TABLE
-- ============================
CREATE TABLE retired_employees (
    retired_id INT AUTO_INCREMENT PRIMARY KEY,
    person_id INT NOT NULL,
    retired_date DATE NOT NULL,
    FOREIGN KEY (person_id) 
        REFERENCES people(person_id)
        ON DELETE CASCADE
);

-- ============================
-- PROMOTIONS TABLE
-- ============================
CREATE TABLE promotions (
    promotion_id INT AUTO_INCREMENT PRIMARY KEY,
    person_id INT NOT NULL,
    old_job_title VARCHAR(50),
    new_job_title VARCHAR(50),
    promotion_date DATE NOT NULL,
    FOREIGN KEY (person_id) 
        REFERENCES people(person_id)
        ON DELETE CASCADE
);

ALTER TABLE promotions
ADD COLUMN old_salary DECIMAL(10,2),
ADD COLUMN new_salary DECIMAL(10,2);

-- ============================
-- PDF GENERATION TABLE
-- ============================
CREATE TABLE generation_pdf (
    pdf_id INT AUTO_INCREMENT PRIMARY KEY,
    person_id INT NOT NULL,
    generated_date DATETIME NOT NULL,
    pdf_type ENUM('travail', 'salaire', 'stage', 'conge', 'demission', 'licenciement', 'retraite'),
    FOREIGN KEY (person_id) 
        REFERENCES people(person_id)
        ON DELETE CASCADE
);

-- ============================
-- EMPLOYEE LEAVES (CONGES) TABLE
-- ============================
CREATE TABLE conges (
    conge_id INT AUTO_INCREMENT PRIMARY KEY,
    person_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    nb_conges INT DEFAULT 22,
    leave_type ENUM('Annuel','Maladie','Maternite','Autre'),
    status ENUM('Approved','Pending','Rejected') DEFAULT 'Pending',
    FOREIGN KEY (person_id) 
        REFERENCES people(person_id)
        ON DELETE CASCADE
);

-- PROCEDURES OF ALL TABLES (ALMOST):
-- ADD EMPLOYEE
DELIMITER $$
CREATE PROCEDURE add_employee(
    IN p_cin VARCHAR(10),
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(20),
    IN p_address VARCHAR(255),
    IN p_city VARCHAR(50),
    IN p_country VARCHAR(50),
    IN p_job_title VARCHAR(50),
    IN p_uni_major VARCHAR(50),
    IN p_uni_level ENUM('Technicien Specialise', 'Licence', 'Master', 'Doctorat', 'Etudiant'),
    IN p_uni_name VARCHAR(255),
    IN p_department_id INT,
    IN p_hire_date DATE,
    IN p_salary DECIMAL(10,2),
    IN p_cv_file VARCHAR(255),
    IN p_birth_date DATE
)
BEGIN
    DECLARE normalized_phone VARCHAR(20);

    IF p_cin NOT REGEXP '^[A-Za-z]{1,2}[0-9]{1,6}$' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'CIN invalide. Format accepté: 1-2 lettres suivies de 1-6 chiffres';
    END IF;

    SET normalized_phone = REPLACE(p_phone, ' ', '');  -- remove spaces

    -- Convert 06XXXXXXXX or 07XXXXXXXX to +2126XXXXXXXX / +2127XXXXXXXX
    IF normalized_phone REGEXP '^0[67][0-9]{8}$' THEN
        SET normalized_phone = CONCAT('+212', SUBSTRING(normalized_phone, 2));
    END IF;

    -- Validate final phone format
    IF normalized_phone NOT REGEXP '^\\+212[67][0-9]{8}$' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Numéro de téléphone invalide. Format accepté: +2126XXXXXXXX ou 06XXXXXXXX';
    END IF;

    IF EXISTS (SELECT 1 FROM people WHERE cin = p_cin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CIN déjà utilisé';
    END IF;

    IF EXISTS (SELECT 1 FROM people WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email déjà utilisé';
    END IF;

    IF EXISTS (SELECT 1 FROM people WHERE phone = normalized_phone) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Numéro de téléphone déjà utilisé';
    END IF;

    INSERT INTO people (
        cin, full_name, email, phone, address, city, country,
        person_type, job_title, uni_major, uni_level, uni_name, department_id,
        hire_date, status, salary, cv_file, birth_date
    ) VALUES (
        p_cin, p_full_name, p_email, normalized_phone, p_address, p_city, p_country,
        'Employe', p_job_title, p_uni_major, p_uni_level, p_uni_name, p_department_id,
        p_hire_date, 'Active', p_salary, p_cv_file, p_birth_date
    );
END $$
DELIMITER ;

-- EDIT EMPLOYEE
DELIMITER $$
CREATE PROCEDURE edit_employee(
    IN p_person_id INT,
    IN p_cin VARCHAR(10),
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(20),
    IN p_address VARCHAR(255),
    IN p_city VARCHAR(50),
    IN p_country VARCHAR(50),
    IN p_job_title VARCHAR(50),
    IN p_uni_major VARCHAR(50),
    IN p_uni_level ENUM('Technicien Specialise', 'Licence', 'Master', 'Doctorat', 'Etudiant'),
    IN p_uni_name VARCHAR(255),
    IN p_department_id INT,
    IN p_hire_date DATE,
    IN p_salary DECIMAL(10,2),
    IN p_cv_file VARCHAR(255),
    IN p_birth_date DATE,
    IN p_status ENUM('Active','Inactive','En attente')
)
BEGIN
    DECLARE normalized_phone VARCHAR(20);

    IF p_cin NOT REGEXP '^[A-Za-z]{1,2}[0-9]{1,6}$' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'CIN invalide';
    END IF;
   
    SET normalized_phone = REPLACE(p_phone, ' ', '');

    IF normalized_phone REGEXP '^0[67][0-9]{8}$' THEN
        SET normalized_phone = CONCAT('+212', SUBSTRING(normalized_phone, 2));
    END IF;

    IF normalized_phone NOT REGEXP '^\\+212[67][0-9]{8}$' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Numéro de téléphone invalide';
    END IF;

    IF EXISTS (SELECT 1 FROM people WHERE cin = p_cin AND person_id <> p_person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CIN déjà utilisé';
    END IF;

    IF EXISTS (SELECT 1 FROM people WHERE email = p_email AND person_id <> p_person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email déjà utilisé';
    END IF;

    IF EXISTS (SELECT 1 FROM people WHERE phone = normalized_phone AND person_id <> p_person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Numéro de téléphone déjà utilisé';
    END IF;
    
    UPDATE people
    SET
        cin = p_cin,
        full_name = p_full_name,
        email = p_email,
        phone = normalized_phone,
        address = p_address,
        city = p_city,
        country = p_country,
        job_title = p_job_title,
        uni_major = p_uni_major,
        uni_level = p_uni_level,
        uni_name = p_uni_name,
        department_id = p_department_id,
        hire_date = p_hire_date,
        salary = p_salary,
        cv_file = p_cv_file,
        birth_date = p_birth_date,
        status = p_status
    WHERE person_id = p_person_id;
END $$
DELIMITER ;

-- Count total employees
DELIMITER $$
CREATE PROCEDURE count_all_employees(OUT total_employees INT)
BEGIN
    SELECT COUNT(*) INTO total_employees FROM people WHERE person_type='Employe';
END $$
DELIMITER ;

-- Count employees per department
DELIMITER $$
CREATE PROCEDURE count_employees_by_department()
BEGIN
    SELECT d.department_name, COUNT(p.person_id) AS total
    FROM people p
    JOIN departments d ON p.department_id = d.department_id
    WHERE p.person_type='Employe'
    GROUP BY d.department_name;
END $$
DELIMITER ;

-- Count employees with promotions
DELIMITER $$
CREATE PROCEDURE count_employees_with_promotions()
BEGIN
    SELECT COUNT(DISTINCT person_id) AS total
    FROM promotions;
END $$
DELIMITER ;

-- Count fired employees
DELIMITER $$
CREATE PROCEDURE count_fired_employees()
BEGIN
    SELECT COUNT(*) AS total FROM fired_employees;
END $$
DELIMITER ;

-- Count retired employees
DELIMITER $$
CREATE PROCEDURE count_retired_employees()
BEGIN
    SELECT COUNT(*) AS total FROM retired_employees;
END $$
DELIMITER ;

-- Count employees currently in leaves
DELIMITER $$
CREATE PROCEDURE count_employees_in_leaves()
BEGIN
    SELECT COUNT(DISTINCT person_id) AS total
    FROM conges
    WHERE person_id IN (SELECT person_id FROM people WHERE person_type='Employe');
END $$
DELIMITER ;

-- Count employees per major
DELIMITER $$
CREATE PROCEDURE count_employees_per_major()
BEGIN
    SELECT uni_major, COUNT(*) AS total
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_major;
END $$
DELIMITER ;

-- Count employees per university
DELIMITER $$
CREATE PROCEDURE count_employees_per_university()
BEGIN
    SELECT uni_name, COUNT(*) AS total
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_name;
END $$
DELIMITER ;

-- Count employees per university level
DELIMITER $$
CREATE PROCEDURE count_employees_per_university_level()
BEGIN
    SELECT uni_level, COUNT(*) AS total
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_level;
END $$
DELIMITER ;

-- Count employees' ages
DELIMITER $$
CREATE PROCEDURE count_employees_age()
BEGIN
    SELECT full_name, FLOOR(DATEDIFF(CURDATE(), birth_date)/365) AS age
    FROM people
    WHERE person_type='Employe';
END $$
DELIMITER ;

-- Count generated PDFs per employee
DELIMITER $$
CREATE PROCEDURE count_pdfs_per_employee()
BEGIN
    SELECT p.full_name, COUNT(g.pdf_id) AS total_pdfs
    FROM people p
    LEFT JOIN generation_pdf g ON p.person_id = g.person_id
    WHERE p.person_type='Employe'
    GROUP BY p.full_name;
END $$
DELIMITER ;

-- Display employees with promotions in descending order
DELIMITER $$
CREATE PROCEDURE display_employees_with_promotions()
BEGIN
    SELECT p.*
    FROM people p
    JOIN promotions pr ON p.person_id = pr.person_id
    WHERE p.person_type='Employe'
    ORDER BY p.full_name DESC;
END $$
DELIMITER ;

-- Display fired employees in descending order
DELIMITER $$
CREATE PROCEDURE display_fired_employees()
BEGIN
    SELECT p.*, f.fired_date, f.reason
    FROM people p
    JOIN fired_employees f ON p.person_id = f.person_id
    ORDER BY p.full_name DESC;
END $$
DELIMITER ;

-- Display retired employees in descending order
DELIMITER $$
CREATE PROCEDURE display_retired_employees()
BEGIN
    SELECT p.*, r.retired_date
    FROM people p
    JOIN retired_employees r ON p.person_id = r.person_id
    ORDER BY p.full_name DESC;
END $$
DELIMITER ;

-- Display employees currently in leaves in descending order
DELIMITER $$
CREATE PROCEDURE display_employees_in_leaves()
BEGIN
    SELECT p.*, c.start_date, c.end_date, c.leave_type, c.status
    FROM people p
    JOIN conges c ON p.person_id = c.person_id
    WHERE p.person_type='Employe'
    ORDER BY p.full_name DESC;
END $$
DELIMITER ;

-- Display employees per major
DELIMITER $$
CREATE PROCEDURE display_employees_per_major()
BEGIN
    SELECT uni_major, GROUP_CONCAT(full_name ORDER BY full_name DESC) AS employees
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_major;
END $$
DELIMITER ;

-- Display employees per university
DELIMITER $$
CREATE PROCEDURE display_employees_per_university()
BEGIN
    SELECT uni_name, GROUP_CONCAT(full_name ORDER BY full_name DESC) AS employees
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_name;
END $$
DELIMITER ;

-- Display employees per university level
DELIMITER $$
CREATE PROCEDURE display_employees_per_university_level()
BEGIN
    SELECT uni_level, GROUP_CONCAT(full_name ORDER BY full_name DESC) AS employees
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_level;
END $$
DELIMITER ;

-- Display the exact retirement date of an employee
DELIMITER $$
CREATE PROCEDURE retirement_date_employee(IN emp_id INT)
BEGIN
    SELECT full_name,
           DATE_ADD(birth_date, INTERVAL 60 YEAR) AS retirement_date
    FROM people
    WHERE person_id = emp_id AND person_type='Employe';
END $$
DELIMITER ;

-- add_intern
DELIMITER $$

CREATE PROCEDURE add_intern (
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_phone VARCHAR(20),
    IN p_major VARCHAR(100),
    IN p_university VARCHAR(100),
    IN p_university_level VARCHAR(50),
    IN p_department VARCHAR(100),
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_is_active BOOLEAN
)
BEGIN
    INSERT INTO interns(
        full_name, email, phone, major, university, university_level,
        department, start_date, end_date, is_active
    ) VALUES (
        p_full_name, p_email, p_phone, p_major, p_university,
        p_university_level, p_department, p_start_date, p_end_date,
        p_is_active
    );
END $$

DELIMITER ;

-- edit_intern
DELIMITER $$

CREATE PROCEDURE edit_intern (
    IN p_intern_id INT,
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_phone VARCHAR(20),
    IN p_major VARCHAR(100),
    IN p_university VARCHAR(100),
    IN p_university_level VARCHAR(50),
    IN p_department VARCHAR(100),
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_is_active BOOLEAN
)
BEGIN
    UPDATE interns
    SET 
        full_name = p_full_name,
        email = p_email,
        phone = p_phone,
        major = p_major,
        university = p_university,
        university_level = p_university_level,
        department = p_department,
        start_date = p_start_date,
        end_date = p_end_date,
        is_active = p_is_active
    WHERE intern_id = p_intern_id;
END $$

DELIMITER ;

-- count_all_interns
DELIMITER $$

CREATE PROCEDURE count_all_interns()
BEGIN
    SELECT COUNT(*) AS total_interns
    FROM interns;
END $$

DELIMITER ;

-- count_interns_by_department
DELIMITER $$

CREATE PROCEDURE count_interns_by_department(IN p_department VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS interns_in_department
    FROM interns
    WHERE department = p_department;
END $$

DELIMITER ;

-- count_active_interns
DELIMITER $$

CREATE PROCEDURE count_active_interns()
BEGIN
    SELECT COUNT(*) AS active_interns
    FROM interns
    WHERE is_active = TRUE;
END $$

DELIMITER ;

-- count_interns_per_major
DELIMITER $$

CREATE PROCEDURE count_interns_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS interns_per_major
    FROM interns
    WHERE major = p_major;
END $$

DELIMITER ;

-- count_interns_per_university
DELIMITER $$

CREATE PROCEDURE count_interns_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS interns_per_university
    FROM interns
    WHERE university = p_university;
END $$

DELIMITER ;

-- count_interns_per_uni_level
DELIMITER $$

CREATE PROCEDURE count_interns_per_uni_level(IN p_university_level VARCHAR(50))
BEGIN
    SELECT COUNT(*) AS interns_per_university_level
    FROM interns
    WHERE university_level = p_university_level;
END $$

DELIMITER ;

-- display_interns_by_department
DELIMITER $$

CREATE PROCEDURE display_interns_by_department(IN p_department VARCHAR(100))
BEGIN
    SELECT *
    FROM interns
    WHERE department = p_department
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- display_active_interns
DELIMITER $$

CREATE PROCEDURE display_active_interns()
BEGIN
    SELECT *
    FROM interns
    WHERE is_active = TRUE
    ORDER BY intern_id DESC;
END $$
delimiter ;
-- display_interns_per_major
DELIMITER $$

CREATE PROCEDURE display_interns_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT *
    FROM interns
    WHERE major = p_major
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- display_interns_per_university
DELIMITER $$

CREATE PROCEDURE display_interns_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT *
    FROM interns
    WHERE university = p_university
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- display_interns_per_uni_level
DELIMITER $$

CREATE PROCEDURE display_interns_per_uni_level(IN p_university_level VARCHAR(50))
BEGIN
    SELECT *
    FROM interns
    WHERE university_level = p_university_level
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- add_candidate
DELIMITER $$

CREATE PROCEDURE add_candidate(
    IN p_cin VARCHAR(20),
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(20),
    IN p_department VARCHAR(100),
    IN p_major VARCHAR(100),
    IN p_university VARCHAR(100),
    IN p_university_level VARCHAR(50),
    IN p_status ENUM('pending','approved','rejected'),
    IN p_full_application BOOLEAN
)
BEGIN
    INSERT INTO candidates (cin, full_name, email, phone, department, major, university, university_level, status, full_application)
    VALUES (p_cin, p_full_name, p_email, p_phone, p_department, p_major, p_university, p_university_level, p_status, p_full_application);
END $$

DELIMITER ;

-- edit_candidate
DELIMITER $$

CREATE PROCEDURE edit_candidate(
    IN p_cin VARCHAR(20),
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(20),
    IN p_department VARCHAR(100),
    IN p_major VARCHAR(100),
    IN p_university VARCHAR(100),
    IN p_university_level VARCHAR(50),
    IN p_status ENUM('pending','approved','rejected'),
    IN p_full_application BOOLEAN
)
BEGIN
    UPDATE candidates
    SET full_name = p_full_name,
        email = p_email,
        phone = p_phone,
        department = p_department,
        major = p_major,
        university = p_university,
        university_level = p_university_level,
        status = p_status,
        full_application = p_full_application
    WHERE cin = p_cin;
END $$

DELIMITER ;

-- count_all_candidates
DELIMITER $$

CREATE PROCEDURE count_all_candidates()
BEGIN
    SELECT COUNT(*) AS total_candidates
    FROM candidates;
END $$

DELIMITER ;

-- count_candidates_per_uni_level
DELIMITER $$

CREATE PROCEDURE count_candidates_per_uni_level(IN p_uni_level VARCHAR(50))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE university_level = p_uni_level;
END $$

DELIMITER ;

-- count_candidates_per_university
DELIMITER $$

CREATE PROCEDURE count_candidates_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE university = p_university;
END $$

DELIMITER ;

-- count_candidates_per_department
DELIMITER $$

CREATE PROCEDURE count_candidates_per_department(IN p_department VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE department = p_department;
END $$

DELIMITER ;

-- count_pending_candidates
DELIMITER $$

CREATE PROCEDURE count_pending_candidates()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE status = 'pending';
END $$

DELIMITER ;

-- count_approved_candidates
DELIMITER $$

CREATE PROCEDURE count_approved_candidates()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE status = 'approved';
END $$

DELIMITER ;

-- count_rejected_candidates
DELIMITER $$

CREATE PROCEDURE count_rejected_candidates()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE status = 'rejected';
END $$

DELIMITER ;

-- count_candidates_with_full_application
DELIMITER $$

CREATE PROCEDURE count_candidates_with_full_application()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE full_application = TRUE;
END $$

DELIMITER ;

-- count_candidates_per_major
DELIMITER $$

CREATE PROCEDURE count_candidates_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE major = p_major;
END $$

DELIMITER ;

-- display_all_candidates
DELIMITER $$

CREATE PROCEDURE display_all_candidates()
BEGIN
    SELECT *
    FROM candidates
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_candidates_per_uni_level
DELIMITER $$

CREATE PROCEDURE display_candidates_per_uni_level(IN p_uni_level VARCHAR(50))
BEGIN
    SELECT *
    FROM candidates
    WHERE university_level = p_uni_level
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_candidates_per_university
DELIMITER $$

CREATE PROCEDURE display_candidates_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT *
    FROM candidates
    WHERE university = p_university
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_candidates_per_department
DELIMITER $$

CREATE PROCEDURE display_candidates_per_department(IN p_department VARCHAR(100))
BEGIN
    SELECT *
    FROM candidates
    WHERE department = p_department
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_pending_candidates
DELIMITER $$

CREATE PROCEDURE display_pending_candidates()
BEGIN
    SELECT *
    FROM candidates
    WHERE status = 'pending'
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_approved_candidates
DELIMITER $$

CREATE PROCEDURE display_approved_candidates()
BEGIN
    SELECT *
    FROM candidates
    WHERE status = 'approved'
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_rejected_candidates
DELIMITER $$

CREATE PROCEDURE display_rejected_candidates()
BEGIN
    SELECT *
    FROM candidates
    WHERE status = 'rejected'
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_candidates_with_full_application
DELIMITER $$

CREATE PROCEDURE display_candidates_with_full_application()
BEGIN
    SELECT *
    FROM candidates
    WHERE full_application = TRUE
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- display_candidates_per_major
DELIMITER $$

CREATE PROCEDURE display_candidates_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT *
    FROM candidates
    WHERE major = p_major
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- add_department
DELIMITER $$

CREATE PROCEDURE add_department(
    IN p_department_name VARCHAR(100),
    IN p_location VARCHAR(100)
)
BEGIN
    INSERT INTO departments (department_name, location)
    VALUES (p_department_name, p_location);
END $$

DELIMITER ;

-- edit_department
DELIMITER $$

CREATE PROCEDURE edit_department(
    IN p_department_id INT,
    IN p_department_name VARCHAR(100),
    IN p_location VARCHAR(100)
)
BEGIN
    UPDATE departments
    SET department_name = p_department_name,
        location = p_location
    WHERE department_id = p_department_id;
END $$

DELIMITER ;

-- delete_department
DELIMITER $$

CREATE PROCEDURE delete_department(
    IN p_department_id INT
)
BEGIN
    DELETE FROM departments
    WHERE department_id = p_department_id;
END $$

DELIMITER ;

-- display_departments
DELIMITER $$

CREATE PROCEDURE display_departments()
BEGIN
    SELECT *
    FROM departments
    ORDER BY department_name ASC;
END $$

DELIMITER ;

-- count_departments
DELIMITER $$

CREATE PROCEDURE count_departments()
BEGIN
    SELECT COUNT(*) AS total_departments
    FROM departments;
END $$

DELIMITER ;

-- display_majors_per_department
DELIMITER $$

CREATE PROCEDURE display_majors_per_department(IN p_department_id INT)
BEGIN
    SELECT DISTINCT uni_major
    FROM people
    WHERE department_id = p_department_id
    ORDER BY uni_major ASC;
END $$

DELIMITER ;

-- count_total_pdfs
DELIMITER $$

CREATE PROCEDURE count_total_pdfs()
BEGIN
    SELECT COUNT(*) AS total_pdfs
    FROM generation_pdf;
END $$

DELIMITER ;

-- count_pdfs_per_type
DELIMITER $$

CREATE PROCEDURE count_pdfs_per_type(IN p_pdf_type VARCHAR(50))
BEGIN
    SELECT COUNT(*) AS total
    FROM generation_pdf
    WHERE pdf_type = p_pdf_type;
END $$

DELIMITER ;

-- count_extra_copies_per_type
DELIMITER $$

CREATE PROCEDURE count_extra_copies_per_type(IN p_pdf_type VARCHAR(50))
BEGIN
    SELECT person_id, COUNT(*) AS pdf_count
    FROM generation_pdf
    WHERE pdf_type = p_pdf_type
    GROUP BY person_id
    HAVING COUNT(*) > 1;
END $$

DELIMITER ;

-- count_pdfs_per_employee
DELIMITER $$
CREATE PROCEDURE count_pdfs_per_employee(IN p_person_id INT)
BEGIN
    SELECT COUNT(*) AS total
    FROM generation_pdf
    WHERE person_id = p_person_id;
END $$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_delete_employee_after_pdf
AFTER INSERT ON generation_pdf
FOR EACH ROW
BEGIN
    IF NEW.pdf_type IN ('demission', 'licenciement', 'retraite') THEN
        DELETE FROM people
        WHERE person_id = NEW.person_id;
    END IF;
END $$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_stage_pdf_flag_convert
AFTER INSERT ON generation_pdf
FOR EACH ROW
BEGIN
    IF NEW.pdf_type = 'stage' THEN
        UPDATE people
        SET status = 'Pending'
        WHERE person_id = NEW.person_id;
    END IF;
END $$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_inactive_employee_on_leave_pdf
AFTER INSERT ON generation_pdf
FOR EACH ROW
BEGIN
    IF NEW.pdf_type IN ('conge','Annuel','maladie','Maternite') THEN
        UPDATE people
        SET status = 'Inactive'
        WHERE person_id = NEW.person_id;
    END IF;
END $$

DELIMITER ;

-- add_promotion
DELIMITER $$

CREATE PROCEDURE add_promotion(
    IN p_person_id INT,
    IN p_percentage_raise DECIMAL(5,2)
)
BEGIN
    DECLARE current_salary DECIMAL(10,2);
    DECLARE new_salary DECIMAL(10,2);
    DECLARE old_job VARCHAR(50);

    SELECT job_title, salary INTO old_job, current_salary
    FROM people
    WHERE person_id = p_person_id;

    SET new_salary = current_salary * (1 + p_percentage_raise / 100);

    INSERT INTO promotions(person_id, old_job_title, new_job_title, promotion_date)
    VALUES (p_person_id, old_job, old_job, CURDATE());

    UPDATE people
    SET salary = new_salary
    WHERE person_id = p_person_id;
END $$

DELIMITER ;

-- edit_promotion
DELIMITER $$

CREATE PROCEDURE edit_promotion(
    IN p_promotion_id INT,
    IN p_new_job_title VARCHAR(50),
    IN p_new_salary DECIMAL(10,2)
)
BEGIN
    UPDATE promotions p
    JOIN people e ON p.person_id = e.person_id
    SET p.new_job_title = p_new_job_title,
        e.salary = p_new_salary
    WHERE p.promotion_id = p_promotion_id;
END $$

DELIMITER ;

-- delete_promotion
DELIMITER $$

CREATE PROCEDURE delete_promotion(IN p_promotion_id INT)
BEGIN
    DELETE FROM promotions
    WHERE promotion_id = p_promotion_id;
END $$

DELIMITER ;

-- count_promotions_last_month
DELIMITER $$

CREATE PROCEDURE count_promotions_last_month()
BEGIN
    SELECT COUNT(*) AS total_promotions
    FROM promotions
    WHERE promotion_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH);
END $$

DELIMITER ;

-- count_promotions_by_department
DELIMITER $$

CREATE PROCEDURE count_promotions_by_department()
BEGIN
    SELECT d.department_name, COUNT(*) AS total_promotions
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    JOIN departments d ON e.department_id = d.department_id
    GROUP BY d.department_name;
END $$

DELIMITER ;

-- count_promotions_per_university
DELIMITER $$

CREATE PROCEDURE count_promotions_per_university()
BEGIN
    SELECT e.uni_name, COUNT(*) AS total_promotions
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    GROUP BY e.uni_name;
END $$

DELIMITER ;

-- count_promotions_per_major
DELIMITER $$

CREATE PROCEDURE count_promotions_per_major()
BEGIN
    SELECT e.uni_major, COUNT(*) AS total_promotions
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    GROUP BY e.uni_major;
END $$

DELIMITER ;

-- display_promotions_by_department
DELIMITER $$

CREATE PROCEDURE display_promotions_by_department()
BEGIN
    SELECT d.department_name, e.full_name, p.old_job_title, p.new_job_title, e.salary, p.promotion_date
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    JOIN departments d ON e.department_id = d.department_id
    ORDER BY d.department_name, e.full_name;
END $$

DELIMITER ;

-- display_promotions_per_university
DELIMITER $$

CREATE PROCEDURE display_promotions_per_university()
BEGIN
    SELECT e.uni_name, e.full_name, p.old_job_title, p.new_job_title, e.salary, p.promotion_date
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    ORDER BY e.uni_name, e.full_name;
END $$

DELIMITER ;

-- display_promotions_per_major
DELIMITER $$

CREATE PROCEDURE display_promotions_per_major()
BEGIN
    SELECT e.uni_major, e.full_name, p.old_job_title, p.new_job_title, e.salary, p.promotion_date
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    ORDER BY e.uni_major, e.full_name;
END $$

DELIMITER ;

-- verify_user_before_adding
DELIMITER $$

CREATE PROCEDURE verify_user_before_adding(
    IN p_cin VARCHAR(20),
    IN p_username VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(20)
)
BEGIN
    DECLARE v_normalized_phone VARCHAR(20);

    -- Phone normalization
    IF LEFT(p_phone, 3) = '06' THEN
        SET v_normalized_phone = CONCAT('+2126', SUBSTRING(p_phone, 3));
    ELSEIF LEFT(p_phone, 3) = '07' THEN
        SET v_normalized_phone = CONCAT('+2127', SUBSTRING(p_phone, 3));
    ELSEIF LEFT(p_phone, 4) = '+212' THEN
        SET v_normalized_phone = p_phone;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid phone format';
    END IF;

    -- Validate phone regex
    IF v_normalized_phone NOT REGEXP '^\\+212[6-7][0-9]{8}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phone number format invalid';
    END IF;

    -- Validate CIN regex (8 digits + optional letter)
    IF p_cin NOT REGEXP '^[0-9]{8}[A-Z]?$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CIN format invalid';
    END IF;

    -- Check CIN uniqueness
    IF EXISTS (SELECT 1 FROM hr_users WHERE hr_id = p_cin)
       OR EXISTS (SELECT 1 FROM people WHERE person_id = p_cin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CIN already exists';
    END IF;

    -- Check username uniqueness
    IF EXISTS (SELECT 1 FROM hr_users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username already exists';
    END IF;

    -- Check email uniqueness
    IF EXISTS (SELECT 1 FROM hr_users WHERE email = p_email)
       OR EXISTS (SELECT 1 FROM people WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email already exists';
    END IF;

    -- Check phone uniqueness
    IF EXISTS (SELECT 1 FROM hr_users WHERE phone = v_normalized_phone)
       OR EXISTS (SELECT 1 FROM people WHERE phone = v_normalized_phone) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Phone already exists';
    END IF;

END $$

DELIMITER ;