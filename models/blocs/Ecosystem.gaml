/**
* Name: Ecosystem
* Based on the internal empty template. 
* Author: Imane
* Tags: 
*/
model Ecosystem

import "../API/API.gaml"
import "InfoRegion.gaml"
import "Transport.gaml"

global {
	list<string> production_outputs_ES <- ["L water", "m3 bois"];
	
    // Water stock and production variables
    float water_stock2 <- 2.08e+19; // Initial stock of water in L
    map<string,float> water_stock_base <- ["Artois-Picardie"::5.07e11,
    							   	  "Rhin-Meuse"::3.702e12, 
    							   	  "Rhone-Méditerranée"::1.5285e13,
    							   	  "Adour-Garonne"::1.947e12,
    							   	  "Loire-Bretagne"::3.225e13,
    							   	  "Seine-Normandie"::2.557e13];
    							   	  
    map<string,float> water_stock <- ["Artois-Picardie"::5.07e11,
    							   	  "Rhin-Meuse"::3.702e12, 
    							   	  "Rhone-Méditerranée"::1.5285e13,
    							   	  "Adour-Garonne"::1.947e12,
    							   	  "Loire-Bretagne"::3.225e13,
    							   	  "Seine-Normandie"::2.557e13];
    
    //float water_production <- 0.97 * water_stock; // Natural replenishment of water per time step (e.g., rainfall)
    float coef_production <- 0.97;
    float available_surface <- 5.51695e+11;
    map<string, float> surface_foret <- load_surface_foret("../includes/data/data_foret.csv");
    map<string, float> repoussement_foret <- load_repoussement_foret("../includes/data/data_foret.csv");
    
    float min_Eau_conso <- 2666.0; //min (32 m cube) 32e3 L par habitant par an => 32000/12 = 2666 litre d'eau par habitant par mois
    float max_Eau_conso <- 8333.0; // max (100 m cube) 1e5 L par habitant par an => 100000/12 = 8333 litre par habitant par mois 
    map<string, map<string, float>> tick_pop_consumption_Region_ES;
    map<string, map<string, float>> tick_production_Region_ES;
    
    init {
    	if (length(coordinator) = 0){
			error "Coordinator agent not found. Ensure you launched the experiment from the Main model";
			// If you see this error when trying to run an experiment, this means the coordinator agent does not exist.
			// Ensure you launched the experiment from the Main model (and not from the bloc model containing the experiment).
		}
		
    }
    
    map<string, float> load_surface_foret(string filename){
		file input_file <- csv_file(filename, ","); // load the csv file and separate the columns
        matrix data_matrix <- matrix(input_file); // put the data in a matrix
        map<string, float> data <- create_map(data_matrix column_at 0, data_matrix column_at 1);
        return data; // return it
	}
	
	map<string, float> load_repoussement_foret(string filename){
		file input_file <- csv_file(filename, ","); // load the csv file and separate the columns
        matrix data_matrix <- matrix(input_file); // put the data in a matrix
        map<string, float> data <- create_map(data_matrix column_at 0, data_matrix column_at 2);
        return data; // return it
	}
}

species ecosystem parent:bloc{
	string name <- "ecosystem";
	
	ecosys_producer producer <- nil;
	ecosys_consumer consumer <- nil;
	
    action update_water_stock(float water_used, string region) {
    	string bassin <- region_bassin[region];
        water_stock[bassin] <- water_stock[bassin] - water_used;
    }
    
    action produce_water{
    	loop bassin over:water_stock.keys{
    		float variation_precipitation <- rnd(50, 100)/100;
    		float precipitation_mensuelle <- water_stock_base[bassin]/12;
    		//water_stock[bassin] <- water_stock[bassin]+precipitation_mensuelle*variation_precipitation  ;
    		water_stock[bassin] <- water_stock[bassin]*(1+coef_production); 
    	}
    }

    // Check if enough water is available for a production demand
    bool is_water_available(float water_needed, string region) {
    	string bassin <- region_bassin[region];
        return water_stock[bassin] > water_needed;
    }
    
    action setup{
	     write "Ecosystem initialized with water stock: " + water_stock + " liters.";
	     list<ecosys_producer> producers <- [];
		 create ecosys_producer number:1 returns:producers; // instanciate the ecosystem production handler
		 create ecosys_consumer number:1 returns:consumers; // instanciate the ecosystem production handler
		 producer <- first(producers);
		 consumer <- first(consumers);
	}
	
	action tick_consumer(list<miniville> mv){
		do collect_last_tick_data();
		do population_consumption(mv);
	}
	
	action tick_distribution{
		
	}
	
	action tick_producer{
		do produce_water;
		do grow_forest;
		do population_production;
	}
	
	action collect_last_tick_data{
		if (cycle >0){
			tick_pop_consumption_Region_ES <- consumer.get_tick_consumption_region();
			tick_production_Region_ES <- producer.get_tick_outputs_produced_region();
			write "[ecosystem] tick_pop_consumption_Region_ES : "+tick_pop_consumption_Region_ES;
		}
		ask ecosys_consumer{ // prepare next tick on consumer side
    		do reset_tick_counters; 
    	}
	}
	
	action population_consumption(list<miniville> Lmv) {
    	ask Lmv{  
    		ask myself.ecosys_consumer{
    			do consume(myself);
    		}
    	}
    }
    
    action population_production {
    	ask ecosys_consumer{
    		ask ecosys_producer{
	    		loop region over: nom_region{
	    			int id <- 0; // fixé à 0 symboliquement
					bool ok <- produce(id, region, myself.consumed[region]);
				}
			}
    	}
    }
	
	
	action grow_forest{
		loop region over: nom_region{
			surface_foret[region] <- surface_foret[region] + repoussement_foret[region];
		}
	}
	
	bool check_surface_foret(string region, float surface_demande){
		// write("ecosystem -> foret dispo : "+surface_foret+", surface demandée : "+surface_demande);
		if(surface_foret[region] > surface_demande){
			return true;
		}
		else{
			return false;
		}
	}
	
	action use_foret(string region, float surface){
		surface_foret[region] <- surface_foret[region] - surface;
	}

	list<string> get_output_resources_labels{
        return production_outputs_ES;
	}
	
	list<string> get_input_resources_labels{
		return [];
	}
	
	action set_external_producer(string product, bloc bloc_agent){
		// do nothing
	}
	
	bool is_surface_available(float surface_needed){
		return available_surface > surface_needed;
	}
	
	action use_surface(float s){
		available_surface <- available_surface - s;
	}
	
	species ecosys_producer parent:production_agent{
		map<string, map<string, float>> tick_production <- [];
		
		init{
			loop region over: nom_region{
				tick_production[region] <- [];
				loop c over: production_outputs_ES{
					tick_production[region][c] <- 0.0;
				}
			}
		}
		
		/* Returns the amounts produced this tick */
		map<string, map<string, float>> get_tick_outputs_produced_region{
			return copy(tick_production);
		}
		
		action set_supplier(string product, bloc bloc_agent){
			
		}
	
		action reset_tick_counters{ // reset impact counters
			loop region over: nom_region{
				loop c over: production_outputs_ES{
					tick_production[region][c] <- 0.0;
				}
			}
		}
		
		// not used
		////////////////////////////////////////////////////////////////////////////
		map<string, map<string, float>> get_tick_inputs_used_region{
			map<string, map<string, float>> tmp <- [];
			return tmp;
		}
		
		/* Returns the amounts emitted this tick */
		map<string, map<string, map<string, float>>> get_tick_emissions_region{
			map<string, map<string, map<string, float>>> tmp <- [];
			return tmp;
		}
		map<string, map<int, map<string, float>>> get_tick_inputs_used_mv{
			map<string, map<int, map<string, float>>> tmp <- [];
			return tmp;
		}
		/* Returns the amounts produced this tick */
		map<string, map<int, map<string, float>>> get_tick_outputs_produced_mv{
			map<string, map<int, map<string, float>>> tmp <- [];
			return tmp;
		}
		/* Returns the amounts emitted this tick */
		map<string, map<int, map<string, map<string, float>>>> get_tick_emissions_mv{
			map<string, map<int, map<string, map<string, float>>>> tmp <- [];
			return tmp;
		}
		////////////////////////////////////////////////////////////////////////////
		
		bool produce(int id, string region, map<string,float> demand){
			bool ok;
			loop c over: demand.keys{
				if (c="L water"){
					ask ecosystem{
						ok <- is_water_available(demand[c],region);
						if (ok){
							do update_water_stock(demand[c],region);
							myself.tick_production[region][c] <- myself.tick_production[region][c] + demand[c];
						}
						else{
							// si la forêt n'est pas disponible dans la région
							// variable qui sauvegarde de combien en ressource depuis quel region
			    			float max_stock <- 0.0;
			    			string max_stock_region;
			    			bool all_penurie <- false;
			    			float demande_restante <- demand[c];
			    			if (demande_restante > 0){
			    				loop while: ((demande_restante > 0) and (! all_penurie)){
			    					max_stock <- 0.0;
			    					all_penurie <- true;
			    					loop depart over: nom_region{
				    					if (region != depart){
				    						if (water_stock[region_bassin[depart]] > max_stock){
				    							max_stock <- water_stock[region_bassin[depart]];
				    							max_stock_region <- depart;
				    							all_penurie <- false;
				    						}
				    					}
				    				}
				    				if (! all_penurie){
				    					write("[Ecosys] find region distributeur : "+max_stock_region+" -> "+region+", "+min([demande_restante, max_stock])+"/"+demande_restante+" "+c);
				    					do update_water_stock(min([demande_restante, max_stock]), max_stock_region);
				    					ask transport{
					    					do ask_transport_externe(max_stock_region, region, c, min([demande_restante, max_stock]));
					    				}
					    				// distribution de resource, on diminue en pénurie pour le région demandeur et diminue en stock pour le région distributeur
					    				demande_restante <- demande_restante - min([demande_restante, max_stock]);
				    				}
				    				else{
				    					write("[Ecosys] no region distributeur pour "+c+" à la région "+region);
				    					ok <- false;
				    				}
			    				}
			    			}
						}
					}
					if (! ok){
						write ("plus d'eau pour "+region+"! ");
					}
				}
				else if (c="m3 bois"){
					ask ecosystem{
						ok <- check_surface_foret(region, demand[c]);
						if (ok){
							do use_foret(region, demand[c]);
							myself.tick_production[region][c] <- myself.tick_production[region][c] + demand[c];
						}
						else{
							// si la forêt n'est pas disponible dans la région
							// variable qui sauvegarde de combien en ressource depuis quel region
			    			float max_stock <- 0.0;
			    			string max_stock_region;
			    			bool all_penurie <- false;
			    			float demande_restante <- demand[c];
			    			if (demande_restante > 0){
			    				loop while: ((demande_restante > 0) and (! all_penurie)){
			    					max_stock <- 0.0;
			    					all_penurie <- true;
			    					loop depart over: nom_region{
				    					if (region != depart){
				    						if (surface_foret[region] > max_stock){
				    							max_stock <- surface_foret[region];
				    							max_stock_region <- depart;
				    							all_penurie <- false;
				    						}
				    					}
				    				}
				    				if (! all_penurie){
				    					write("[Ecosys] find region distributeur : "+max_stock_region+" -> "+region+", "+min([demande_restante, max_stock])+"/"+demande_restante+" "+c);
				    					ask transport{
					    					do ask_transport_externe(max_stock_region, region, c, min([demande_restante, max_stock]));
					    				}
					    				// distribution de resource, on diminue en pénurie pour le région demandeur et diminue en stock pour le région distributeur
					    				do use_foret(max_stock_region, min([demande_restante, max_stock]));
					    				demande_restante <- demande_restante - min([demande_restante, max_stock]);
				    				}
				    				else{
				    					write("[Ecosys] no region distributeur pour "+c+" à la région "+region);
				    					ok <- false;
				    				}
			    				}
			    			}
						}
					}
					if(! ok){
						write("plus de foret pour "+region+" !");
					}
				}
				else{
					write ("demande inconnu : "+c);
				}
					
			}
			return ok; // always return 'ok' signal
		}
	}
	
	species ecosys_consumer parent:consumption_agent{
		
		map<string, map<string, float>> consumed <- [];
		
		map<string, map<string, float>> get_tick_consumption_region{
			return copy(consumed);
		}
		
		map<string, map<int, map<string, float>>> get_tick_consumption_mv{
			// not used
			map<string, map<int, map<string, float>>> tmp <- []; 
			return tmp;
		}
		init{
			loop r over: nom_region{
				consumed[r]<-[];
				consumed[r]["L water"] <- 0.0;
			}
		}
		
		action reset_tick_counters{ 
    		loop r over: nom_region{
				consumed[r]["L water"] <- 0.0;
			}
		}
		
		action consume(miniville mv){  //TODO: implémentation dépend de la façon dont la population et les minivilles sont implémentés
			string r <- mv.region;
			
			// calcul de la consommation
			consumed[r]["L water"] <- consumed[r]["L water"]+rnd(min_Eau_conso, max_Eau_conso) * mv.nb_population*echelle;
		}
		
	}
}

experiment run_ecosystem type: gui {
    
	output {
		display Eau_information {
			
			chart "Population direct consumption" type: series  size: {0.5,0.5} position: {0, 0} {
				loop r over:nom_region{
					// write "tick_pop_consumption_Region_ES => "+tick_pop_consumption_Region_ES[r]["L water"];
				    data r value: cycle>0 ? tick_pop_consumption_Region_ES[r]["L water"] : 0;    
				}
			}
			chart "Production" type: series  size: {0.5,0.5} position: {0, 0.5} {
				loop r over:nom_region{
					// write "tick_production_Region_ES => "+tick_pop_consumption_Region_ES[r]["L water"];
				    data r value: cycle>0 ? tick_production_Region_ES[r]["L water"] : 0;    
				}
			}
			chart "Stock eau" type: series  size: {0.5,0.5} position: {0.5, 0} {
				loop bassin over: water_stock.keys{
				    data bassin value: cycle>0 ? water_stock[bassin] : 0;    
				}
			}
			chart "Stock forêt" type: series  size: {0.5,0.5} position: {0.5, 0.5} {
				loop r over:nom_region{
					data r value: cycle>0 ? surface_foret[r] : 0;    
				}
			}
		}
	}
}