CREATE TABLE IF NOT EXISTS vicenza_mdt_profiles (
    identifier VARCHAR(80) NOT NULL,
    image TEXT NULL,
    notes LONGTEXT NULL,
    tags LONGTEXT NULL,
    risk_level VARCHAR(20) DEFAULT 'low',
    updated_by VARCHAR(80) NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier)
);

CREATE TABLE IF NOT EXISTS vicenza_mdt_incidents (
    id INT NOT NULL AUTO_INCREMENT,
    type VARCHAR(40) DEFAULT 'criminal',
    title VARCHAR(255) NOT NULL,
    summary LONGTEXT NULL,
    status VARCHAR(40) DEFAULT 'open',
    priority VARCHAR(20) DEFAULT 'normal',
    location VARCHAR(255) NULL,
    involved LONGTEXT NULL,
    evidence LONGTEXT NULL,
    charges LONGTEXT NULL,
    created_by VARCHAR(80) NOT NULL,
    created_by_name VARCHAR(120) NULL,
    assigned_to VARCHAR(80) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_status (status),
    INDEX idx_created_by (created_by)
);

CREATE TABLE IF NOT EXISTS vicenza_mdt_warrants (
    id INT NOT NULL AUTO_INCREMENT,
    target_type VARCHAR(20) NOT NULL,
    target_identifier VARCHAR(80) NULL,
    target_label VARCHAR(160) NULL,
    plate VARCHAR(20) NULL,
    title VARCHAR(255) NOT NULL,
    reason LONGTEXT NULL,
    status VARCHAR(30) DEFAULT 'pending',
    expires_at DATETIME NULL,
    created_by VARCHAR(80) NOT NULL,
    created_by_name VARCHAR(120) NULL,
    approved_by VARCHAR(80) NULL,
    approved_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_status (status),
    INDEX idx_target_identifier (target_identifier),
    INDEX idx_plate (plate)
);

CREATE TABLE IF NOT EXISTS vicenza_mdt_bolos (
    id INT NOT NULL AUTO_INCREMENT,
    type VARCHAR(30) DEFAULT 'person',
    title VARCHAR(255) NOT NULL,
    description LONGTEXT NULL,
    person_identifier VARCHAR(80) NULL,
    person_label VARCHAR(160) NULL,
    plate VARCHAR(20) NULL,
    image TEXT NULL,
    priority VARCHAR(20) DEFAULT 'normal',
    status VARCHAR(30) DEFAULT 'active',
    created_by VARCHAR(80) NOT NULL,
    created_by_name VARCHAR(120) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_status (status),
    INDEX idx_plate (plate)
);

CREATE TABLE IF NOT EXISTS vicenza_mdt_charges (
    id INT NOT NULL AUTO_INCREMENT,
    code VARCHAR(40) NOT NULL,
    category VARCHAR(80) DEFAULT 'Generale',
    title VARCHAR(255) NOT NULL,
    description LONGTEXT NULL,
    fine INT DEFAULT 0,
    jail INT DEFAULT 0,
    active TINYINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_code (code)
);

CREATE TABLE IF NOT EXISTS vicenza_mdt_announcements (
    id INT NOT NULL AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    message LONGTEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'normal',
    created_by VARCHAR(80) NOT NULL,
    created_by_name VARCHAR(120) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS vicenza_mdt_audit (
    id INT NOT NULL AUTO_INCREMENT,
    officer_identifier VARCHAR(80) NULL,
    officer_name VARCHAR(120) NULL,
    action VARCHAR(80) NOT NULL,
    payload LONGTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_action (action),
    INDEX idx_officer_identifier (officer_identifier)
);