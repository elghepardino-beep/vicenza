-- Aggiungi le colonne job2 alla tabella users
ALTER TABLE `users` 
ADD COLUMN `job2` VARCHAR(50) NOT NULL DEFAULT 'unemployed',
ADD COLUMN `job2_grade` INT(11) NOT NULL DEFAULT 0;

-- Tabella jobs2 (specchio di jobs)
CREATE TABLE IF NOT EXISTS `jobs2` (
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) NOT NULL,
  `whitelisted` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabella job2_grades (specchio di job_grades)
CREATE TABLE IF NOT EXISTS `job2_grades` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `grade` INT(11) NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) NOT NULL,
  `salary` INT(11) NOT NULL DEFAULT 0,
  `skin_male` LONGTEXT NULL,
  `skin_female` LONGTEXT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Job2 di default: unemployed
INSERT INTO `jobs2` (`name`, `label`, `whitelisted`) VALUES 
('unemployed', 'Disoccupato', 0);

INSERT INTO `job2_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
('unemployed', 0, 'unemployed', 'Disoccupato', 200);

-- Esempio job2 aggiuntivi
INSERT INTO `jobs2` (`name`, `label`, `whitelisted`) VALUES 
('fisher', 'Pescatore', 0),
('lumberjack', 'Boscaiolo', 0);

INSERT INTO `job2_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
('fisher', 0, 'apprentice', 'Apprendista', 300),
('fisher', 1, 'pro', 'Professionista', 500),
('lumberjack', 0, 'apprentice', 'Apprendista', 300),
('lumberjack', 1, 'pro', 'Professionista', 500);