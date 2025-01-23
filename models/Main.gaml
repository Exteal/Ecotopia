/**
* Name: Main (MOSIMA)
* Authors: Maël Franceschetti, Cédric Herpson, Jean-Daniel Kant
* Mail: firstname.lastname@lip6.fr
*/

model Main

import "API/API.gaml"
// import "blocs/Urbanism.gaml"
import "blocs/Agricultural.gaml"
import "blocs/Energy.gaml"
import "blocs/Ecosystem.gaml"
import "blocs/StringUtils.gaml"
import "blocs/Demography.gaml"
import "blocs/Transport.gaml"


/**
 * This is the main section of the simulation. Here, we instanciate our blocs, and launch the simulation through the coordinator.
 */
global{
	bool use_gis <- true; // use GIS or not (needed to spatialise, instanciate territory species, and to display the map)
	float step <- 1 #month; // the simulation step is a month
	bool enable_demography <- true; // true to activate the demography (births, deaths), else false
	
	// GIS files
	file shape_file_cities <- file("../includes/shapefiles/cities_france.shp");
	file shape_file_bounds <- file("../includes/shapefiles/boundaries_france.shp");
	file shape_file_forests <- file("../includes/shapefiles/forests_france_light.shp");
	file shape_rivers_lakes <- file("../includes/shapefiles/rivers_france_light.shp");
	file shape_mountains <- file("../includes/shapefiles/mountains_france_1300m.shp");
	geometry shape <- envelope(shape_file_bounds);
	
	init{
		if(use_gis){
			// setup the territory :
			create fronteers from: shape_file_bounds;
			create mountain from: shape_mountains;
			create forest from: shape_file_forests;
			create water_source from: shape_rivers_lakes;
			create city from: shape_file_cities;
		}
	
		// instanciate the blocs (E, A and R blocs here):
		create residents number:1{
			enabled <- enable_demography; // enable or not the demography
		}
		create agricultural number:1;
		create energy number:1;
		// create urbanisme number:1;
		create ecosystem number:1;
		create coordinator number:1; // instanciate the coordinator
		create transport number:1;
		
		// start simulation :
		ask coordinator{ 
			do register_all_blocs; // register the blocs in the coordinator
			do start; // start the simulation
		}
	}
}

/**
 * We define only one experiment in the main file : the display of the GIS. 
 * Other displays are defined in the blocs experiments.
 */
experiment display_gis type: gui {
	output {
		display country_map type: java2D {
			species fronteers aspect: base ;
			species mountain aspect: base transparency: 0.15;
			species forest aspect: base transparency: 0.15;
			species water_source aspect: base ;
			species city aspect: base ;
		}
	}
}

