/**
* Name: API (MOSIMA)
* Authors: Maël Franceschetti, Cédric Herpson, Jean-Daniel Kant
* Mail: firstname.lastname@lip6.fr
*/


model API

/*
 * Species used to represent a bloc.
 * A bloc as the following main functions :
 *  - be the interface between its producers and the other blocs
 *  - define the consumption behavior of the population related to this bloc
 * See the example blocs supplied alongside the API for more details.
 */
species bloc{
	string name; // the name of the bloc
	production_agent producer; // the production agent of the bloc
	
	/* Initialize the bloc */
	action setup virtual:true;
	
	/* Execute the next tick */
	action tick_consumer(list<miniville> mv) virtual:true;
	
	action tick_distribution virtual:true;
	
	action tick_producer virtual:true;
	
	/* Returns the labels of the resources used by this bloc for production (inputs) */
	action get_input_resources_labels virtual:true type:list<string>;
	
	/* Returns the labels of the resources produced by this bloc (outputs) */
	action get_output_resources_labels virtual:true type:list<string>;
	
}

/* 
 * Species used to represent all the production of a bloc.
 * Note : this species will be implemented as a micro-species of its bloc.
 * See the example blocs supplied alongside the API for more details.
 */
species production_agent{
	
	/* Produce the given resources in the requested quantities. Return true in case of success. */
	action produce(int id, string region, map<string, float> demand) virtual:true type:bool;
	
	// +--------------------------------------------------------------------+
	// | à choisir l'un des deux celle qui est adapté à votre problématique |
	// +--------------------------------------------------------------------+
	
	// get tick au sein des régions
	
	/* Returns all the resources used for the production this tick */
	action get_tick_inputs_used_region virtual:true type: map<string, map<string, float>>;
	/* Returns the amounts produced this tick */
	action get_tick_outputs_produced_region virtual:true type: map<string, map<string, float>>;
	/* Returns the amounts emitted this tick */
	action get_tick_emissions_region virtual:true type: map<string, map<string, map<string, float>>>; 
	// map<region, map<type d'emission, map<source d'emission, valeur>>>
	// par exemple : ["Ile-de-France"::["gCO2e emissions"::["kg_bovine"::200.0, "kg_legumes::50.0, ...]]]
	
	
	
	// get tick au sein des mini-villes
	
	/* Returns all the resources used for the production this tick */
	action get_tick_inputs_used_mv virtual:true type: map<string, map<int, map<string, float>>>;
	/* Returns the amounts produced this tick */
	action get_tick_outputs_produced_mv virtual:true type: map<string, map<int, map<string, float>>>;
	/* Returns the amounts emitted this tick */
	action get_tick_emissions_mv virtual:true type: map<string, map<int, map<string, map<string, float>>>>;		
	// map<region, map<id mini-ville, map<type d'emission, map<source d'emission, valeur>>>
	// par exemple : ["Ile-de-France"::[0::["gCO2e emissions"::["kg_bovine"::200.0, "kg_legumes::50.0, ...]]]]
	
	/* Defines an external producer for a resource */
	action set_supplier(string product, bloc bloc_agent) virtual:true; 
}

/* 
 * Species used to detail the consumption behavior of the population, related to a bloc.
 * Every tick, this behavior will be applied to all the individuals of the population.
 * Note : this species will be implemented as a micro-species of its bloc.
 * See the example blocs supplied alongside the API for more details.
 */
species consumption_agent{
	
	/* Apply the consumption behavior of a given human. Return true in case of success. */
	action consume(miniville mv) virtual:true;
	
	/* Returns the amount of resources consumed by the population this tick */
	
	// +--------------------------------------------------------------------+
	// | à choisir l'un des deux celle qui est adapté à votre problématique |
	// +--------------------------------------------------------------------+
	
	// consommation au sein des régions
	action get_tick_consumption_region virtual:true type: map<string, map<string, float>>;
	
	// consommation au sein des mini-villes
	action get_tick_consumption_mv virtual:true type: map<string, map<int, map<string, float>>>;
}

species distribution_agent{
	
	/* Apply the distribution behavior of a given human.*/
	action distribution virtual:true;
	
	/* Returns the amount of resources consumed by the population this tick */
	
	// +--------------------------------------------------------------------+
	// | à choisir l'un des deux celle qui est adapté à votre problématique |
	// +--------------------------------------------------------------------+
	
	// distribution de ressources au sein des régions
	action get_tick_distribution_region virtual:true type: map<string, map<string, float>>;
	action get_tick_reception_region virtual:true type: map<string, map<string, float>>;
	
	// distribution de ressources au sein des mini-villes
	action get_tick_distribution_mv virtual:true type: map<string, map<int, map<string, float>>>;
	action get_tick_reception_mv virtual:true type: map<string, map<int, map<string, float>>>;
}
	
species human{
	int age <- 0; // age (in years)
	string gender <- ""; // gender
	map<string,string> additional_attributes <- [];														
}

species miniville{
	// id de référence
	int id <- 0;
	// région où se situe
	string region <- "";
	int nb_population <- 10000;
	// à compléter par le secteur urbanisme
	map<string, map<int, int>> repartition_age <- [];
	map<string, map<string, int>> repartition_additional_attributes <- [];
}


/* 
 * Species used to implement the coordinator agent of the simulation.
 * This is a unique agent in charge of the following tasks :
 * - register all the instanciated blocs
 * - link the producers with their suppliers
 * - execute each tick, coordinating blocs and other agents
 * This agent is not intended to be modified. If this is the case, please check beforehand the possible 
 * side effects of the modifications on the system as a whole.
 */
species coordinator{
	map<string, bloc> registered_blocs <- []; // the blocs handled by the coordinator
	map<string, bloc> producers <-[]; // the producer registered for each resource
	list<string> scheduling <- []; // blocs execution order
	bool started <- false; // the current state of the coordinator (started or waiting)

	/* Returns all the agents of a given species and its subspecies */
	list<agent> get_all_instances(species<agent> spec) {
	    return spec.population +  spec.subspecies accumulate (get_all_instances(each));
	}
	
	/* Register a bloc : it will be handled by the coordinator */
	action register_bloc(bloc b){
		list<string> products <- [];
		ask b{
			do setup; // setup the bloc
			products <- get_output_resources_labels();
		}
		registered_blocs[b.name] <- b;
		loop p over: products{ // register this bloc as producer of product p
			producers[p] <- b;
		}
		if !(b.name in scheduling){
			scheduling <- scheduling + b.name;
		}
	}
	
	/* Affects the external producers (when a bloc needs the production of another bloc, this one is its exernal producer) */
	action affect_suppliers{
		loop b over: registered_blocs.values{
			list<string> resources_used <- b.get_input_resources_labels();
			loop r over: resources_used{
				if(producers.keys contains r){ // there is a known producer for this resource/good
					ask b.producer {
						do set_supplier(r, myself.producers[r]); // link the external producer to the bloc needing it
					}
				}
			}
		}
	}

	/* Defines the scheduling of the different blocs */
	action set_scheduling(list<string> scheduling_order){
		write("[coordinateur] set scheduling : "+scheduling_order);
		scheduling <- scheduling_order;
	}

	/* Register all the blocs */
	action register_all_blocs{
		list<bloc> blocs <- get_all_instances(bloc);
		
		loop b over: blocs{
			do register_bloc(b); //register the bloc
		}
		write "registered blocs : "+registered_blocs;
		
		// set_scheduling
		//list<string> scheduling_order <- ["residents", "urbanisme", "transport", "agricultural", "energy", "ecosystem"];
		list<string> scheduling_order <- ["residents", "transport", "agricultural", "energy", "ecosystem"];
		do set_scheduling(scheduling_order);
		
		if length(scheduling) = 0{
			write("[API] set default scheduling order");
			scheduling <- blocs collect each.name; // set default scheduling order
		}
		else{
			write("[API] scheduling : "+scheduling);
		}
		do affect_suppliers();
	}
	
	/* Start the simulation */
	action start{
		started <- true;
	}
	
	/* Stop the simulation */
	action stop{
		started <- false;
	}
	
	/* Reflex : move to the next tick of the simulation */
	reflex new_tick when: started{
		write("\n[coordinator] cycle "+cycle);
		//list<human> pop <- get_all_instances(human);	
		list<miniville> pop <- get_all_instances(miniville);

		// consommation
		write("\n[API] consommation");
		loop bloc_name over: scheduling{ // move to next tick for all blocs, following the defined scheduling
			// write("[API] scheduling : "+scheduling);
			// write("[API] registered_blocs : "+ registered_blocs);
			// write("[API] : next bloc name : "+bloc_name);
			if bloc_name in registered_blocs.keys{
				write("[API] : bloc name : "+bloc_name);
				ask registered_blocs[bloc_name]{
					do tick_consumer(pop);
					write("[API] : bloc name : "+bloc_name+" consumption finish");
				}
			}else{
				write "warning : bloc "+bloc_name+" not found !";
				// if you have this warning, check that the name of the blocs in the scheduling are correct
			}
		}
		
		if (cycle > 0){
			// discribution
			write("\n[API] distribution");
			loop bloc_name over: scheduling{ // move to next tick for all blocs, following the defined scheduling
			    // write("[API] scheduling : "+scheduling);
				// write("[API] registered_blocs : "+ registered_blocs);
				// write("[API] : next bloc name : "+bloc_name);
				if bloc_name in registered_blocs.keys{
					write("[API] : bloc name : "+bloc_name);
					ask registered_blocs[bloc_name]{
						do tick_distribution;
						write("[API] : bloc name : "+bloc_name+" distribution finish");
					}
				}else{
					write "warning : bloc "+bloc_name+" not found !";
					// if you have this warning, check that the name of the blocs in the scheduling are correct
				}
			}
		}
		
		// production
		write("\n[API] production");
		loop bloc_name over: scheduling{ // move to next tick for all blocs, following the defined scheduling
			// write("[API] scheduling : "+scheduling);
			// write("[API] registered_blocs : "+ registered_blocs);
			// write("[API] : next bloc name : "+bloc_name);
			if bloc_name in registered_blocs.keys{
				write("[API] : bloc name : "+bloc_name);
				ask registered_blocs[bloc_name]{
					do tick_producer;
					write("[API] : bloc name : "+bloc_name+" production finish");
				}
			}else{
				write "warning : bloc "+bloc_name+" not found !";
				// if you have this warning, check that the name of the blocs in the scheduling are correct
			}
		}
	}
}

/* Territory species (used to represent GIS elements) */

species fronteers {
	string type; 
	rgb color <- #whitesmoke;
	rgb border_color <- #dimgray;
	aspect base {
		draw shape color: color border: border_color;
	}
}

species mountain {
	string type; 
	rgb color <- #silver;
	
	aspect base {
		draw shape color: color ;
	}
}

species forest {
	string type; 
	rgb color <- #mediumseagreen;
	
	aspect base {
		draw shape color: color ;
	}
}

species water_source {
	string type; 
	rgb color <- #royalblue;
	
	aspect base {
		draw shape color: color ;
	}
}

species city {
	string type; 
	rgb color <- #black;
	
	aspect base {
		draw circle(2.0#px) color: color ;
	}
}



