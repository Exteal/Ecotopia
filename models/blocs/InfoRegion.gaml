/**
* Name: InfoRegion
* Based on the internal empty template. 
* Author: romai
* Tags: 
*/


model InfoRegion

/* Insert your model definition here */

global{
	list<string> nom_region <- ["Auvergne-Rhône-Alpes", 
								"Bourgogne-Franche-Comté",
								"Bretagne",
								"Centre-Val-de-Loire",
								"Grand Est",
								"Hauts-de-France",
								"Île-de-France",
								"Normandie",
								"Nouvelle-Aquitaine",
								"Occitanie",
								"Pays de la Loire",
								"Provence-Alpes-Côte d'Azur"];
								
	// Distances en m²							
	map<string,float> superfecie_region <- ["Auvergne-Rhône-Alpes"::6.9711e+10, 
								"Bourgogne-Franche-Comté"::4.78e+10,
								"Bretagne"::2.7208e+10 ,
								"Centre-Val-de-Loire"::3.9151e+10,
								"Grand Est"::5.7441e+10 ,
								"Hauts-de-France"::3.18e+10,
								"Île-de-France"::1.2012e+10,
								"Normandie"::2.9906e+10,
								"Nouvelle-Aquitaine"::8.41e+10,
								"Occitanie"::7.2724e+10,
								"Pays de la Loire"::3.2082e+10,
								"Provence-Alpes-Côte d'Azur"::3.14e+10];
	
	// le bassin que chaque région utilise pour ses besoins en eau						
	map<string,string> region_bassin <-["Auvergne-Rhône-Alpes"::"Rhone-Méditerranée", 
								"Bourgogne-Franche-Comté"::"Rhone-Méditerranée",
								"Bretagne"::"Loire-Bretagne",
								"Centre-Val-de-Loire"::"Loire-Bretagne",
								"Grand Est"::"Rhin-Meuse",
								"Hauts-de-France"::"Artois-Picardie",
								"Île-de-France"::"Seine-Normandie",
								"Normandie"::"Seine-Normandie",
								"Nouvelle-Aquitaine"::"Adour-Garonne",
								"Occitanie"::"Adour-Garonne",
								"Pays de la Loire"::"Loire-Bretagne",
								"Provence-Alpes-Côte d'Azur"::"Rhone-Méditerranée"];
								
	// pour chaque région on a une référence des minivilles	par leurs ids					
	map<string, list<int>> mv_region <- [];
	
	int echelle <- 100;	// modélisation de la France à l'échelle 1/echelle
}