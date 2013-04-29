-- MySQL dump 10.13  Distrib 5.5.30, for Linux (x86_64)
--
-- Host: localhost    Database: queuetest
-- ------------------------------------------------------
-- Server version	5.5.30-30.2-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `queue_test_aitable`
--

DROP TABLE IF EXISTS `queue_test_aitable`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `queue_test_aitable` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `transaction_id` mediumint(8) unsigned DEFAULT NULL,
  `payload` text,
  PRIMARY KEY (`id`),
  KEY `transaction_unique` (`transaction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `queue_test_aitable`
--

LOCK TABLES `queue_test_aitable` WRITE;
/*!40000 ALTER TABLE `queue_test_aitable` DISABLE KEYS */;
/*!40000 ALTER TABLE `queue_test_aitable` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `queue_transaction`
--

DROP TABLE IF EXISTS `queue_transaction`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `queue_transaction` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `queue_transaction`
--

LOCK TABLES `queue_transaction` WRITE;
/*!40000 ALTER TABLE `queue_transaction` DISABLE KEYS */;
/*!40000 ALTER TABLE `queue_transaction` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'queuetest'
--
/*!50003 DROP PROCEDURE IF EXISTS `queue_test_aitable_dequeue` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DELIMITER ;;
-- CREATE DEFINER=`root`@`localhost` PROCEDURE `queue_test_aitable_dequeue`(wanted_msgs INT)
CREATE PROCEDURE `queue_test_aitable_dequeue`(wanted_msgs INT)
BEGIN INSERT INTO queue_transaction VALUES (); SET @TRANS_ID=LAST_INSERT_ID(); UPDATE queue_test_aitable SET `transaction_id` = @TRANS_ID WHERE `transaction_id` IS NULL LIMIT wanted_msgs; SELECT `id`, `transaction_id`, `payload` FROM queue_test_aitable WHERE `transaction_id` = @TRANS_ID; END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-04-28 23:20:33
