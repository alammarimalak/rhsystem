CREATE DATABASE systemrh;
USE systemrh;

-- ============================
-- TABLE UTILISATEURS RH
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
);

-- ============================
-- TABLE DEPARTEMENTS
-- ============================
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100)
);

-- ============================
-- TABLE PERSONNES (Employés, Stagiaires, Candidats)
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
-- TABLE EMPLOYES LICENCIES
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
-- TABLE EMPLOYES RETRAITES
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
-- TABLE PROMOTIONS
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
-- TABLE GENERATION PDF
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
-- TABLE CONGES EMPLOYES
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

-- PROCEDURES DE TOUTES LES TABLES (PRESQUE):
-- AJOUTER EMPLOYE
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

    SET normalized_phone = REPLACE(p_phone, ' ', '');  -- supprimer les espaces

    -- Convertir 06XXXXXXXX ou 07XXXXXXXX en +2126XXXXXXXX / +2127XXXXXXXX
    IF normalized_phone REGEXP '^0[67][0-9]{8}$' THEN
        SET normalized_phone = CONCAT('+212', SUBSTRING(normalized_phone, 2));
    END IF;

    -- Valider le format final du numéro de téléphone
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

-- MODIFIER EMPLOYE
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

-- Compter le total des employés
DELIMITER $$
CREATE PROCEDURE count_all_employees(OUT total_employees INT)
BEGIN
    SELECT COUNT(*) INTO total_employees FROM people WHERE person_type='Employe';
END $$
DELIMITER ;

-- Compter les employés par département
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

-- Compter les employés avec promotions
DELIMITER $$
CREATE PROCEDURE count_employees_with_promotions()
BEGIN
    SELECT COUNT(DISTINCT person_id) AS total
    FROM promotions;
END $$
DELIMITER ;

-- Compter les employés licenciés
DELIMITER $$
CREATE PROCEDURE count_fired_employees()
BEGIN
    SELECT COUNT(*) AS total FROM fired_employees;
END $$
DELIMITER ;

-- Compter les employés retraités
DELIMITER $$
CREATE PROCEDURE count_retired_employees()
BEGIN
    SELECT COUNT(*) AS total FROM retired_employees;
END $$
DELIMITER ;

-- Compter les employés actuellement en congé
DELIMITER $$
CREATE PROCEDURE count_employees_in_leaves()
BEGIN
    SELECT COUNT(DISTINCT person_id) AS total
    FROM conges
    WHERE person_id IN (SELECT person_id FROM people WHERE person_type='Employe');
END $$
DELIMITER ;

-- Compter les employés par spécialité
DELIMITER $$
CREATE PROCEDURE count_employees_per_major()
BEGIN
    SELECT uni_major, COUNT(*) AS total
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_major;
END $$
DELIMITER ;

-- Compter les employés par université
DELIMITER $$
CREATE PROCEDURE count_employees_per_university()
BEGIN
    SELECT uni_name, COUNT(*) AS total
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_name;
END $$
DELIMITER ;

-- Compter les employés par niveau universitaire
DELIMITER $$
CREATE PROCEDURE count_employees_per_university_level()
BEGIN
    SELECT uni_level, COUNT(*) AS total
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_level;
END $$
DELIMITER ;

-- Compter les âges des employés
DELIMITER $$
CREATE PROCEDURE count_employees_age()
BEGIN
    SELECT full_name, FLOOR(DATEDIFF(CURDATE(), birth_date)/365) AS age
    FROM people
    WHERE person_type='Employe';
END $$
DELIMITER ;

-- Compter les PDFs générés par employé
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

-- Afficher les employés avec promotions en ordre décroissant
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

-- Afficher les employés licenciés en ordre décroissant
DELIMITER $$
CREATE PROCEDURE display_fired_employees()
BEGIN
    SELECT p.*, f.fired_date, f.reason
    FROM people p
    JOIN fired_employees f ON p.person_id = f.person_id
    ORDER BY p.full_name DESC;
END $$
DELIMITER ;

-- Afficher les employés retraités en ordre décroissant
DELIMITER $$
CREATE PROCEDURE display_retired_employees()
BEGIN
    SELECT p.*, r.retired_date
    FROM people p
    JOIN retired_employees r ON p.person_id = r.person_id
    ORDER BY p.full_name DESC;
END $$
DELIMITER ;

-- Afficher les employés actuellement en congé en ordre décroissant
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

-- Afficher les employés par spécialité
DELIMITER $$
CREATE PROCEDURE display_employees_per_major()
BEGIN
    SELECT uni_major, GROUP_CONCAT(full_name ORDER BY full_name DESC) AS employees
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_major;
END $$
DELIMITER ;

-- Afficher les employés par université
DELIMITER $$
CREATE PROCEDURE display_employees_per_university()
BEGIN
    SELECT uni_name, GROUP_CONCAT(full_name ORDER BY full_name DESC) AS employees
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_name;
END $$
DELIMITER ;

-- Afficher les employés par niveau universitaire
DELIMITER $$
CREATE PROCEDURE display_employees_per_university_level()
BEGIN
    SELECT uni_level, GROUP_CONCAT(full_name ORDER BY full_name DESC) AS employees
    FROM people
    WHERE person_type='Employe'
    GROUP BY uni_level;
END $$
DELIMITER ;

-- Afficher la date exacte de retraite d'un employé
DELIMITER $$
CREATE PROCEDURE retirement_date_employee(IN emp_id INT)
BEGIN
    SELECT full_name,
           DATE_ADD(birth_date, INTERVAL 60 YEAR) AS retirement_date
    FROM people
    WHERE person_id = emp_id AND person_type='Employe';
END $$
DELIMITER ;

-- ajouter_stagiaire
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

-- modifier_stagiaire
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

-- compter_tous_les_stagiaires
DELIMITER $$

CREATE PROCEDURE count_all_interns()
BEGIN
    SELECT COUNT(*) AS total_interns
    FROM interns;
END $$

DELIMITER ;

-- compter_stagiaires_par_departement
DELIMITER $$

CREATE PROCEDURE count_interns_by_department(IN p_department VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS interns_in_department
    FROM interns
    WHERE department = p_department;
END $$

DELIMITER ;

-- compter_stagiaires_actifs
DELIMITER $$

CREATE PROCEDURE count_active_interns()
BEGIN
    SELECT COUNT(*) AS active_interns
    FROM interns
    WHERE is_active = TRUE;
END $$

DELIMITER ;

-- compter_stagiaires_par_specialite
DELIMITER $$

CREATE PROCEDURE count_interns_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS interns_per_major
    FROM interns
    WHERE major = p_major;
END $$

DELIMITER ;

-- compter_stagiaires_par_universite
DELIMITER $$

CREATE PROCEDURE count_interns_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS interns_per_university
    FROM interns
    WHERE university = p_university;
END $$

DELIMITER ;

-- compter_stagiaires_par_niveau_uni
DELIMITER $$

CREATE PROCEDURE count_interns_per_uni_level(IN p_university_level VARCHAR(50))
BEGIN
    SELECT COUNT(*) AS interns_per_university_level
    FROM interns
    WHERE university_level = p_university_level;
END $$

DELIMITER ;

-- afficher_stagiaires_par_departement
DELIMITER $$

CREATE PROCEDURE display_interns_by_department(IN p_department VARCHAR(100))
BEGIN
    SELECT *
    FROM interns
    WHERE department = p_department
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- afficher_stagiaires_actifs
DELIMITER $$

CREATE PROCEDURE display_active_interns()
BEGIN
    SELECT *
    FROM interns
    WHERE is_active = TRUE
    ORDER BY intern_id DESC;
END $$
delimiter ;
-- afficher_stagiaires_par_specialite
DELIMITER $$

CREATE PROCEDURE display_interns_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT *
    FROM interns
    WHERE major = p_major
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- afficher_stagiaires_par_universite
DELIMITER $$

CREATE PROCEDURE display_interns_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT *
    FROM interns
    WHERE university = p_university
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- afficher_stagiaires_par_niveau_uni
DELIMITER $$

CREATE PROCEDURE display_interns_per_uni_level(IN p_university_level VARCHAR(50))
BEGIN
    SELECT *
    FROM interns
    WHERE university_level = p_university_level
    ORDER BY intern_id DESC;
END $$

DELIMITER ;

-- ajouter_candidat
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

-- modifier_candidat
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

-- compter_tous_les_candidats
DELIMITER $$

CREATE PROCEDURE count_all_candidates()
BEGIN
    SELECT COUNT(*) AS total_candidates
    FROM candidates;
END $$

DELIMITER ;

-- compter_candidats_par_niveau_uni
DELIMITER $$

CREATE PROCEDURE count_candidates_per_uni_level(IN p_uni_level VARCHAR(50))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE university_level = p_uni_level;
END $$

DELIMITER ;

-- compter_candidats_par_universite
DELIMITER $$

CREATE PROCEDURE count_candidates_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE university = p_university;
END $$

DELIMITER ;

-- compter_candidats_par_departement
DELIMITER $$

CREATE PROCEDURE count_candidates_per_department(IN p_department VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE department = p_department;
END $$

DELIMITER ;

-- compter_candidats_en_attente
DELIMITER $$

CREATE PROCEDURE count_pending_candidates()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE status = 'pending';
END $$

DELIMITER ;

-- compter_candidats_approuves
DELIMITER $$

CREATE PROCEDURE count_approved_candidates()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE status = 'approved';
END $$

DELIMITER ;

-- compter_candidats_rejetes
DELIMITER $$

CREATE PROCEDURE count_rejected_candidates()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE status = 'rejected';
END $$

DELIMITER ;

-- compter_candidats_avec_candidature_complete
DELIMITER $$

CREATE PROCEDURE count_candidates_with_full_application()
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE full_application = TRUE;
END $$

DELIMITER ;

-- compter_candidats_par_specialite
DELIMITER $$

CREATE PROCEDURE count_candidates_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT COUNT(*) AS total
    FROM candidates
    WHERE major = p_major;
END $$

DELIMITER ;

-- afficher_tous_les_candidats
DELIMITER $$

CREATE PROCEDURE display_all_candidates()
BEGIN
    SELECT *
    FROM candidates
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_par_niveau_uni
DELIMITER $$

CREATE PROCEDURE display_candidates_per_uni_level(IN p_uni_level VARCHAR(50))
BEGIN
    SELECT *
    FROM candidates
    WHERE university_level = p_uni_level
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_par_universite
DELIMITER $$

CREATE PROCEDURE display_candidates_per_university(IN p_university VARCHAR(100))
BEGIN
    SELECT *
    FROM candidates
    WHERE university = p_university
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_par_departement
DELIMITER $$

CREATE PROCEDURE display_candidates_per_department(IN p_department VARCHAR(100))
BEGIN
    SELECT *
    FROM candidates
    WHERE department = p_department
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_en_attente
DELIMITER $$

CREATE PROCEDURE display_pending_candidates()
BEGIN
    SELECT *
    FROM candidates
    WHERE status = 'pending'
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_approuves
DELIMITER $$

CREATE PROCEDURE display_approved_candidates()
BEGIN
    SELECT *
    FROM candidates
    WHERE status = 'approved'
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_rejetes
DELIMITER $$

CREATE PROCEDURE display_rejected_candidates()
BEGIN
    SELECT *
    FROM candidates
    WHERE status = 'rejected'
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_avec_candidature_complete
DELIMITER $$

CREATE PROCEDURE display_candidates_with_full_application()
BEGIN
    SELECT *
    FROM candidates
    WHERE full_application = TRUE
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- afficher_candidats_par_specialite
DELIMITER $$

CREATE PROCEDURE display_candidates_per_major(IN p_major VARCHAR(100))
BEGIN
    SELECT *
    FROM candidates
    WHERE major = p_major
    ORDER BY full_name ASC;
END $$

DELIMITER ;

-- ajouter_departement
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

-- modifier_departement
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

-- supprimer_departement
DELIMITER $$

CREATE PROCEDURE delete_department(
    IN p_department_id INT
)
BEGIN
    DELETE FROM departments
    WHERE department_id = p_department_id;
END $$

DELIMITER ;

-- afficher_departements
DELIMITER $$

CREATE PROCEDURE display_departments()
BEGIN
    SELECT *
    FROM departments
    ORDER BY department_name ASC;
END $$

DELIMITER ;

-- compter_departements
DELIMITER $$

CREATE PROCEDURE count_departments()
BEGIN
    SELECT COUNT(*) AS total_departments
    FROM departments;
END $$

DELIMITER ;

-- afficher_specialites_par_departement
DELIMITER $$

CREATE PROCEDURE display_majors_per_department(IN p_department_id INT)
BEGIN
    SELECT DISTINCT uni_major
    FROM people
    WHERE department_id = p_department_id
    ORDER BY uni_major ASC;
END $$

DELIMITER ;

-- compter_total_pdfs
DELIMITER $$

CREATE PROCEDURE count_total_pdfs()
BEGIN
    SELECT COUNT(*) AS total_pdfs
    FROM generation_pdf;
END $$

DELIMITER ;

-- compter_pdfs_par_type
DELIMITER $$

CREATE PROCEDURE count_pdfs_per_type(IN p_pdf_type VARCHAR(50))
BEGIN
    SELECT COUNT(*) AS total
    FROM generation_pdf
    WHERE pdf_type = p_pdf_type;
END $$

DELIMITER ;

-- compter_copies_supplementaires_par_type
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

-- compter_pdfs_par_employe
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

-- ajouter_promotion
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

-- modifier_promotion
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

-- supprimer_promotion
DELIMITER $$

CREATE PROCEDURE delete_promotion(IN p_promotion_id INT)
BEGIN
    DELETE FROM promotions
    WHERE promotion_id = p_promotion_id;
END $$

DELIMITER ;

-- compter_promotions_le_mois_dernier
DELIMITER $$

CREATE PROCEDURE count_promotions_last_month()
BEGIN
    SELECT COUNT(*) AS total_promotions
    FROM promotions
    WHERE promotion_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH);
END $$

DELIMITER ;

-- compter_promotions_par_departement
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

-- compter_promotions_par_universite
DELIMITER $$

CREATE PROCEDURE count_promotions_per_university()
BEGIN
    SELECT e.uni_name, COUNT(*) AS total_promotions
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    GROUP BY e.uni_name;
END $$

DELIMITER ;

-- compter_promotions_par_specialite
DELIMITER $$

CREATE PROCEDURE count_promotions_per_major()
BEGIN
    SELECT e.uni_major, COUNT(*) AS total_promotions
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    GROUP BY e.uni_major;
END $$

DELIMITER ;

-- afficher_promotions_par_departement
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

-- afficher_promotions_par_universite
DELIMITER $$

CREATE PROCEDURE display_promotions_per_university()
BEGIN
    SELECT e.uni_name, e.full_name, p.old_job_title, p.new_job_title, e.salary, p.promotion_date
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    ORDER BY e.uni_name, e.full_name;
END $$

DELIMITER ;

-- afficher_promotions_par_specialite
DELIMITER $$

CREATE PROCEDURE display_promotions_per_major()
BEGIN
    SELECT e.uni_major, e.full_name, p.old_job_title, p.new_job_title, e.salary, p.promotion_date
    FROM promotions p
    JOIN people e ON p.person_id = e.person_id
    ORDER BY e.uni_major, e.full_name;
END $$

DELIMITER ;

-- verifier_utilisateur_avant_ajout
DELIMITER $$

CREATE PROCEDURE verify_user_before_adding(
    IN p_cin VARCHAR(20),
    IN p_username VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(20)
)
BEGIN
    DECLARE v_normalized_phone VARCHAR(20);

    -- Normalisation du numéro de téléphone
    IF LEFT(p_phone, 3) = '06' THEN
        SET v_normalized_phone = CONCAT('+2126', SUBSTRING(p_phone, 3));
    ELSEIF LEFT(p_phone, 3) = '07' THEN
        SET v_normalized_phone = CONCAT('+2127', SUBSTRING(p_phone, 3));
    ELSEIF LEFT(p_phone, 4) = '+212' THEN
        SET v_normalized_phone = p_phone;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Format de numéro de téléphone invalide';
    END IF;

    -- Valider l'expression régulière du téléphone
    IF v_normalized_phone NOT REGEXP '^\\+212[6-7][0-9]{8}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Format du numéro de téléphone invalide';
    END IF;

    -- Valider l'expression régulière CIN (8 chiffres + lettre optionnelle)
    IF p_cin NOT REGEXP '^[0-9]{8}[A-Z]?$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Format CIN invalide';
    END IF;

    -- Vérifier l'unicité CIN
    IF EXISTS (SELECT 1 FROM hr_users WHERE hr_id = p_cin)
       OR EXISTS (SELECT 1 FROM people WHERE person_id = p_cin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CIN existe déjà';
    END IF;

    -- Vérifier l'unicité du nom d'utilisateur
    IF EXISTS (SELECT 1 FROM hr_users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nom d'utilisateur existe déjà';
    END IF;

    -- Vérifier l'unicité de l'email
    IF EXISTS (SELECT 1 FROM hr_users WHERE email = p_email)
       OR EXISTS (SELECT 1 FROM people WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email existe déjà';
    END IF;

    -- Vérifier l'unicité du téléphone
    IF EXISTS (SELECT 1 FROM hr_users WHERE phone = v_normalized_phone)
       OR EXISTS (SELECT 1 FROM people WHERE phone = v_normalized_phone) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Téléphone existe déjà';
    END IF;

END $$
DELIMITER ;

-- supprimer_employe
DELIMITER ;
CREATE PROCEDURE delete_employee(IN p_person_id INT)
BEGIN
    DELETE FROM people
    WHERE person_id = p_person_id AND person_type = 'Employe';
END $$
DELIMITER ;

-- supprimer_stagiaire
DELIMITER ;
CREATE PROCEDURE delete_intern(IN p_intern_id INT) 
BEGIN
    DELETE FROM interns
    WHERE intern_id = p_intern_id;
END $$
DELIMITER ;

-- supprimer_candidat
DELIMITER ;
CREATE PROCEDURE delete_candidate(IN p_cin VARCHAR(20))
BEGIN
    DELETE FROM candidates
    WHERE cin = p_cin;
END $$
DELIMITER ;

-- supprimer_conges
DELIMITER ;
CREATE PROCEDURE delete_conge(IN p_conge_id INT)
BEGIN
    DELETE FROM conges
    WHERE conge_id = p_conge_id;
END $$
DELIMITER ;

-- supprimer_employes_retraites
DELIMITER ;
CREATE PROCEDURE delete_retired_employee(IN p_retired_id INT)
BEGIN
    DELETE FROM retired_employees
    WHERE retired_id = p_retired_id;
END $$
DELIMITER ;

-- supprimer_employes_licencies
DELIMITER ;
CREATE PROCEDURE delete_fired_employee(IN p_fired_id INT)
BEGIN
    DELETE FROM fired_employees
    WHERE fired_id = p_fired_id;
END $$
DELIMITER ;

-- supprimer_generation_pdf
DELIMITER ;
CREATE PROCEDURE delete_generation_pdf(IN p_pdf_id INT)
BEGIN
    DELETE FROM generation_pdf
    WHERE pdf_id = p_pdf_id;
END $$
DELIMITER ;

-- supprimer_departement
DELIMITER ;
CREATE PROCEDURE delete_department(IN p_department_id INT)
BEGIN
    DELETE FROM departments
    WHERE department_id = p_department_id;
END $$
DELIMITER ;

-- supprimer_promotion
DELIMITER ;
CREATE PROCEDURE delete_promotion(IN p_promotion_id INT)
BEGIN
    DELETE FROM promotions
    WHERE promotion_id = p_promotion_id;
END $$
DELIMITER ;

-- mettre_a_jour_nom_complet_rh
DELIMITER $$

CREATE PROCEDURE UpdateHRFullName(
    IN p_hr_id INT,
    IN p_new_full_name VARCHAR(100)
)
BEGIN
    DECLARE user_exists INT;
    
    SELECT COUNT(*) INTO user_exists FROM hr_users WHERE hr_id = p_hr_id;

    IF user_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilisateur RH non trouvé';
    END IF;
    
    IF p_new_full_name IS NULL OR TRIM(p_new_full_name) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le nom complet ne peut pas être vide';
    END IF;
    
    IF LENGTH(p_new_full_name) < 2 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le nom complet doit contenir au moins 2 caractères';
    END IF;
    
    UPDATE hr_users
    SET full_name = TRIM(p_new_full_name)
    WHERE hr_id = p_hr_id;

    SELECT 'Nom complet mis à jour avec succès' AS message;
END$$

DELIMITER ;

-- mettre_a_jour_mot_de_passe_pour_rh
DELIMITER $$

CREATE PROCEDURE ChangeHRPassword(
    IN p_hr_id INT,
    IN p_current_password VARCHAR(255),
    IN p_new_password VARCHAR(255),
    IN p_confirm_password VARCHAR(255)
)
BEGIN
    DECLARE user_exists INT;
    DECLARE stored_password VARCHAR(255);
    
    SELECT COUNT(*), password_hash INTO user_exists, stored_password
    FROM hr_users WHERE hr_id = p_hr_id;

    IF user_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilisateur RH non trouvé';
    END IF;
    
    IF p_current_password IS NULL OR p_current_password != stored_password THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le mot de passe actuel est incorrect';
    END IF;
    
    IF p_new_password IS NULL OR TRIM(p_new_password) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le nouveau mot de passe ne peut pas être vide';
    END IF;
    
    IF LENGTH(p_new_password) < 8 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le nouveau mot de passe doit contenir au moins 8 caractères';
    END IF;
    
    IF p_new_password != p_confirm_password THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le nouveau mot de passe et la confirmation ne correspondent pas';
    END IF;
    
    IF p_new_password = p_current_password THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le nouveau mot de passe ne peut pas être identique au mot de passe actuel';
    END IF;
    
    UPDATE hr_users
    SET password_hash = p_new_password
    WHERE hr_id = p_hr_id;

    SELECT 'Mot de passe mis à jour avec succès' AS message;
END$$

DELIMITER ;

-- valider_et_mettre_a_jour_numero_rh

DELIMITER $$

CREATE PROCEDURE UpdateHRPhoneNumber(
    IN p_hr_id INT,
    IN p_new_phone VARCHAR(20)
)
BEGIN
    DECLARE user_exists INT;
    DECLARE phone_exists INT;
    
    SELECT COUNT(*) INTO user_exists FROM hr_users WHERE hr_id = p_hr_id;

    IF user_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilisateur RH non trouvé';
    END IF;
    
    IF p_new_phone IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le numéro de téléphone est requis';
    END IF;
    
    SET p_new_phone = REPLACE(REPLACE(p_new_phone, ' ', ''), '-', '');
    
    IF NOT (
        p_new_phone REGEXP '^(07|06)[0-9]{8}$' OR
        p_new_phone REGEXP '^\\+212[67][0-9]{8}$' OR
        p_new_phone REGEXP '^00212[67][0-9]{8}$' OR
        p_new_phone REGEXP '^212[67][0-9]{8}$'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Numéro de téléphone marocain invalide. Doit commencer par 06, 07, +2126, +2127, 2126, 2127, 002126 ou 002127';
    END IF;
    
    SELECT COUNT(*) INTO phone_exists
    FROM hr_users
    WHERE phone = p_new_phone AND hr_id != p_hr_id;

    IF phone_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le numéro de téléphone existe déjà pour un autre utilisateur';
    END IF;
    
    UPDATE hr_users
    SET phone = p_new_phone
    WHERE hr_id = p_hr_id;

    SELECT 'Numéro de téléphone mis à jour avec succès' AS message;
END$$

DELIMITER ;

-- mettre_a_jour_statut_rh
DELIMITER $$

CREATE PROCEDURE ChangeHRStatus(
    IN p_hr_id INT,
    IN p_new_status ENUM('Active','Inactive')
)
BEGIN
    DECLARE user_exists INT;
    DECLARE current_status ENUM('Active','Inactive');
    
    SELECT COUNT(*), status INTO user_exists, current_status
    FROM hr_users WHERE hr_id = p_hr_id;

    IF user_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilisateur RH non trouvé';
    END IF;
    
    IF p_new_status NOT IN ('Active', 'Inactive') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Le statut doit être Actif ou Inactif';
    END IF;
    
    IF current_status = p_new_status THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Le statut est déjà défini sur ', p_new_status);
    END IF;
    
    UPDATE hr_users
    SET status = p_new_status
    WHERE hr_id = p_hr_id;

    SELECT CONCAT('Statut changé à ', p_new_status, ' avec succès') AS message;
END$$

DELIMITER ;

-- afficher_profil_rh
DELIMITER $$

CREATE PROCEDURE DisplayHRDetails(IN p_hr_id INT)
BEGIN
    DECLARE user_exists INT;
    
    SELECT COUNT(*) INTO user_exists FROM hr_users WHERE hr_id = p_hr_id;

    IF user_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Utilisateur RH non trouvé';
    END IF;
    
    SELECT hr_id,cin, full_name,email,username,phone,status,last_login FROM hr_users WHERE hr_id = p_hr_id;
END$$

DELIMITER ;
