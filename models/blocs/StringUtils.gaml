/**
* Name: StringUtils
* Usefuls strings used in multiple blocs
* Author: rh4
* Tags: 
*/


model StringUtils

global {
	// HUMAN SPECIES ATTRIBUTES KEYS
	string activite <- "activite";
	string loisir <- "loisir";
	
	string K_logement <- "logement";
	
	string externe <- "externe";
	
	// 'ACTIVITE' VALUES
	string travail <- "travail";
	string scolarite <- "scolarite";
	string retraite <- "retraite";
	
	// 'LOISIR' VALUES
	string espace_naturel <- "espace_natuel";
	string domicile <- "domicile";
	string exterieur <- "exterieur";
	
	// BUILDINGS TYPES
	string K_wood_building <- "wood building";
	string K_modular_house <- "modular house";
	string K_camp <- "camp";
	
	// UNITS
	string K_kg_bois <- "kg_bois";
	string K_m3_bois <- "m3 bois";
	string K_m2_land <- "m² land";
	string K_kg_coton <- "kg_coton";
	string any_energy <- "any_energy";
	string K_gCO2e_emissions <- "gCO2e emissions";
	
}