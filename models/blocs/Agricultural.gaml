/**
* Name: Agricultural bloc (MOSIMA)
* Authors: Maël Franceschetti, Cédric Herpson, Jean-Daniel Kant
* Mail: firstname.lastname@lip6.fr
*/

model Agricultural

import "../API/API.gaml"
import "Ecosystem.gaml"
import "InfoRegion.gaml"
import "Transport.gaml"

/**
 * We define here the global variables and data of the bloc. Some are needed for the displays (charts, series...).
 */
global{
	
	/* Setup */
	list<string> production_outputs_A <- ["kg_bovine", "kg_porc", "kg_poulet", "kg_vegetables", "kg_coton"];
	list<string> production_inputs_A <- ["L water", "any_energy", "m² land"];
	list<string> production_emissions_A <- ["gCO2e emissions"];
	
	// surface de production en France métropolitaine
	list<map<string, float>> data_surface <- load_surface_data("../includes/data/mosima_data_agri_reg.csv");
	map<string, float> espace_ferme <- data_surface[0]; // m²
	map<string, float> espace_legumes <- data_surface[1]; // m²
	
	// surface coton (surface nationale)
	float espace_coton <- 503150000.0; // m²
	
	/* Production data */
	// energy en kWh
	map production_output_inputs_A <- [
		"kg_bovine"::["L water"::15415.0, "any_energy"::2.4, "m² land"::269.0, "gCO2e emissions"::8.29],
		"kg_porc"::["L water"::5988.0, "any_energy"::0.42, "m² land"::11.5, "gCO2e emissions"::1.03],
		"kg_poulet"::["L water"::4325.0, "any_energy"::8.23, "m² land"::6.5, "gCO2e emissions"::0.82],
		"kg_vegetables"::["L water"::322.0, "any_energy"::0.3, "m² land"::0.66, "gCO2e emissions"::0.26],
		"kg_coton"::["L water"::5200.0, "any_energy"::0.2, "m² land"::3.33, "gCO2e emissions"::0.35]
	];
	map production_output_emissions_A <- [
		"kg_bovine"::["gCO2e emissions"::8.29],
		"kg_porc"::["gCO2e emissions"::1.03],
		"kg_poulet"::["gCO2e emissions"::0.82],
		"kg_vegetables"::["gCO2e emissions"::0.26],
		"kg_coton"::["gCO2e emissions"::0.35]
	];
	
	
	/* Consumption data */
	map indivudual_consumption_A <- ["kg_bovine"::1.83, "kg_porc"::2.66, "kg_poulet"::2.33, "kg_vegetables"::10.44]; // monthly consumption per individual of the population.
	
	/* Counters & Stats */
	
	map<string, map<string, float>> tick_production_A <- [];
	map<string, map<string, float>> tick_consumption_A <- [];
	map<string, map<string, float>> tick_distribution_A <- [];
	map<string, map<string, float>> tick_reception_A <- [];
	map<string, map<string, float>> tick_resources_used_A <- [];
	map<string, map<string, float>> tick_surface_used_A <- [];
	map<string, map<string, float>> tick_surface_manque_A <- [];
	map<string, map<string, map<string, float>>> tick_emissions_A <- [];
	map<string, map<string, float>> tick_penurie_A <- [];
	map<string, map<string, float>> tick_stock_A <- [];
	
	init{ // a security added to avoid launching an experiment without the other blocs
		if (length(coordinator) = 0){
			error "Coordinator agent not found. Ensure you launched the experiment from the Main model";
			// If you see this error when trying to run an experiment, this means the coordinator agent does not exist.
			// Ensure you launched the experiment from the Main model (and not from the bloc model containing the experiment).
		}
	}
	
	list<map<string, float>> load_surface_data(string filename){
		file input_file <- csv_file(filename, ","); // load the csv file and separate the columns
        matrix data_matrix <- matrix(input_file); // put the data in a matrix
        map<string, float> surface_viande <- create_map(data_matrix column_at 0, data_matrix column_at 1);
        map<string, float> surface_legumes <- create_map(data_matrix column_at 0, data_matrix column_at 2);
        list<map<string, float>> data <- [surface_viande, surface_legumes];
        return data; // return it
	}
}

/**
 * We define here the agricultural bloc as a species.
 * We implement the methods of the API.
 * We also add methods specific to this bloc to consumption behavior of the population.
 */
species agricultural parent:bloc{
	string name <- "agricultural";
	
	agri_producer producer <- nil;
	agri_consumer consumer <- nil;
	agri_distributeur distributeur <- nil;
	
	action setup{
		list<agri_producer> producers <- [];
		list<agri_consumer> consumers <- [];
		list<agri_distributeur> distributeurs <- [];
		create agri_producer number:1 returns:producers; // instanciate the agricultural production handler
		create agri_consumer number:1 returns:consumers; // instanciate the agricultural consumption handler
		create agri_distributeur number:1 returns:distributeurs; // instanciate the agricultural distribution handler
		producer <- first(producers);
		consumer <- first(consumers);
		distributeur <- first(distributeurs);
	}
	
	action tick_consumer(list<miniville> mv) {
		do collect_last_tick_data();
		do population_consumption(mv);
	}
	
	action tick_distribution{
		do population_distribution;
	}
	
	action tick_producer{
		do population_production;
	}
	
	action set_external_producer(string product, bloc bloc_agent){
		ask producer{
			do set_supplier(product, bloc_agent);
		}
	}
	
	production_agent get_producer{
		return producer;
	}

	list<string> get_output_resources_labels{
		return production_outputs_A;
	}
	
	list<string> get_input_resources_labels{
		return production_inputs_A;
	}
	
	list<string> get_emissions_labels{
		return production_emissions_A;
	}
	
	action collect_last_tick_data{
		if(cycle > 0){ // skip it the first tick
			tick_consumption_A <- consumer.get_tick_consumption_region(); // collect consumption behaviors
	    	tick_resources_used_A <- producer.get_tick_inputs_used_region(); // collect resources used
	    	tick_production_A <- producer.get_tick_outputs_produced_region(); // collect production
	    	tick_distribution_A <- distributeur.get_tick_distribution_region();
	    	tick_reception_A <- distributeur.get_tick_reception_region();
	    	tick_surface_used_A <- producer.get_tick_surface_used(); // collect surface used
	    	tick_surface_manque_A <- producer.get_tick_surface_manque(); // collect surface manque
	    	tick_emissions_A <- producer.get_tick_emissions_region(); // collect emissions
	    	tick_penurie_A <- consumer.get_tick_penurie(); // collect emissions
    		tick_stock_A <- consumer.get_tick_stock();	// collect stock
    		
    		float tick_production_bovine;
			float tick_production_porc;
			float tick_production_poulet;
			float tick_production_legumes;
			float tick_production_coton;
			float tick_consommation_bovine;
			float tick_consommation_porc;
			float tick_consommation_poulet;
			float tick_consommation_legumes;
			float tick_distribution_bovine;
			float tick_distribution_porc;
			float tick_distribution_poulet;
			float tick_distribution_legumes;
			float tick_reception_bovine;
			float tick_reception_porc;
			float tick_reception_poulet;
			float tick_reception_legumes;
			float tick_emission_bovine;
			float tick_emission_porc;
			float tick_emission_poulet;
			float tick_emission_legumes;
			float tick_emission_coton;
			float tick_emission_total;
    		float tick_surface_used_viandes;
    		float tick_surface_used_legumes;
    		// float tick_surface_used_coton;
    		float tick_surface_manque_viandes;
    		float tick_surface_manque_legumes;
    		// float tick_surface_manque_coton;
    		float tick_water_used_agricole;
    		// float tick_water_manque_agricole;
    		float tick_energy_used_agricole;
    		// float tick_energy_manque_agricole;
    		float tick_penurie_bovine;
    		float tick_penurie_porc;
    		float tick_penurie_poulet;
    		float tick_penurie_legumes;
    		float tick_stock_bovine;
    		float tick_stock_porc;
    		float tick_stock_poulet;
    		float tick_stock_legumes;
    		
    		loop region over: nom_region{
    			tick_production_bovine <- tick_production_A[region]["kg_bovine"];
    			tick_production_porc <- tick_production_A[region]["kg_porc"];
    			tick_production_poulet <- tick_production_A[region]["kg_poulet"];
    			tick_production_legumes <- tick_production_A[region]["kg_vegetables"];
    			tick_production_coton <- tick_production_A[region]["kg_coton"];
    			tick_consommation_bovine <- tick_consumption_A[region]["kg_bovine"];
    			tick_consommation_porc <- tick_consumption_A[region]["kg_porc"];
    			tick_consommation_poulet <- tick_consumption_A[region]["kg_poulet"];
    			tick_consommation_legumes <- tick_consumption_A[region]["kg_vegetables"];
    			tick_distribution_bovine <- tick_distribution_A[region]["kg_bovine"];
    			tick_distribution_porc <- tick_distribution_A[region]["kg_porc"];
    			tick_distribution_poulet <- tick_distribution_A[region]["kg_poulet"];
    			tick_distribution_legumes <- tick_distribution_A[region]["kg_vegetables"];
    			tick_reception_bovine <- tick_reception_A[region]["kg_bovine"];
    			tick_reception_porc <- tick_reception_A[region]["kg_porc"];
    			tick_reception_poulet <- tick_reception_A[region]["kg_poulet"];
    			tick_reception_legumes <- tick_reception_A[region]["kg_vegetables"];
	    		tick_emission_bovine <- tick_emissions_A[region]["gCO2e emissions"]["kg_bovine"];
	    		tick_emission_porc <- tick_emissions_A[region]["gCO2e emissions"]["kg_porc"];
	    		tick_emission_poulet <- tick_emissions_A[region]["gCO2e emissions"]["kg_poulet"];
	    		tick_emission_legumes <- tick_emissions_A[region]["gCO2e emissions"]["kg_vegetables"];
	    		tick_emission_coton <- tick_emissions_A[region]["gCO2e emissions"]["kg_coton"];
	    		tick_emission_total <- tick_emission_bovine +  tick_emission_porc + tick_emission_poulet + tick_emission_legumes + tick_emission_coton;
	    		tick_surface_used_viandes <- tick_surface_used_A[region]["kg_meat"];
	    		tick_surface_used_legumes <- tick_surface_used_A[region]["kg_vegetables"];
	    		// tick_surface_used_coton
	    		tick_surface_manque_viandes <- tick_surface_manque_A[region]["kg_meat"];
	    		tick_surface_manque_legumes <- tick_surface_manque_A[region]["kg_vegetables"];
	    		// tick_surface_manque_coton
	    		tick_water_used_agricole <- tick_resources_used_A[region]["L water"];
	    		// tick_water_manque_agricole <- tick_resources_manque_A[region]["L water"];
	    		tick_energy_used_agricole <- tick_resources_used_A[region]["any_energy"];
	    		// tick_energy_manque_agricole <- tick_resources_manque_A[region]["any energy"];
	    		tick_penurie_bovine <- tick_penurie_A[region]["kg_bovine"];
	    		tick_penurie_porc <- tick_penurie_A[region]["kg_porc"];
	    		tick_penurie_poulet <- tick_penurie_A[region]["kg_poulet"];
	    		tick_penurie_legumes <- tick_penurie_A[region]["kg_vegetables"];
	    		tick_stock_bovine <- tick_stock_A[region]["kg_bovine"];
	    		tick_stock_porc <- tick_stock_A[region]["kg_poulet"];
	    		tick_stock_poulet <- tick_stock_A[region]["kg_porc"];
	    		tick_stock_legumes <- tick_stock_A[region]["kg_vegetables"];
    			save [tick_production_bovine, tick_production_porc, tick_production_poulet, tick_production_legumes, tick_production_coton,
	    			tick_consommation_bovine, tick_consommation_porc, tick_consommation_poulet, tick_consommation_legumes,
	    			tick_distribution_bovine, tick_distribution_porc, tick_distribution_poulet, tick_distribution_legumes,
	    			tick_reception_bovine, tick_reception_porc, tick_reception_poulet, tick_reception_legumes,
	    			// tick_emission_bovine, tick_emission_porc, tick_emission_poulet, tick_emission_legumes, tick_emission_coton,
	    			tick_emission_total,
	    			tick_surface_used_viandes, tick_surface_used_legumes,
	    			tick_surface_manque_viandes, tick_surface_manque_legumes,
	    			tick_water_used_agricole,
		    		// tick_water_manque_agricole,
	    			tick_energy_used_agricole,
	    			// tick_energy_manque_agricole,
	    			tick_penurie_bovine, tick_penurie_porc, tick_penurie_poulet, tick_penurie_legumes,
	    			tick_stock_bovine, tick_stock_porc, tick_stock_poulet, tick_stock_legumes
	    		] to:"../resultat/agriculture/data/data_agricultural_"+region+".csv" rewrite: cycle>1 ? false : true header: true ;
    		}
    		
	    	ask agri_consumer{
    			do set_stock(tick_production_A);
    		}
	    	
	    	ask agri_consumer{ // prepare new tick on consumer side
	    		do reset_tick_counters;
	    	}
	    	
	    	ask agri_producer{ // prepare new tick on producer side
	    		do reset_tick_counters;
	    	}
    	}
	}
    
    action population_consumption(list<miniville> mv) {
    	// calcul consommation au sein des mini-villes
    	ask mv{
    		ask myself.agri_consumer{
    			do consume(myself);
    		}
    	}
    	// calcul de stock/pénurie
    	ask agri_consumer{
    		do gestion_stock();
    	}
    }
    
    action population_production{
    	ask agri_consumer{ // produce the required quantities
    		ask agri_producer{
    			loop region over: nom_region{
    				loop c over: myself.consumed[region].keys{
    					// write("[Agri] c : "+c);
    					// write("[Agri] consumed[region] : "+myself.consumed[region]);
    					// write("[Agri] consumed[region][c] : "+myself.consumed[region][c]);
    					// write("[Agri] penurie[region] : "+myself.penurie[region]);
    					// write("[Agri] penurie[region][c] : "+myself.penurie[region][c]);
	    				bool ok <- produce(-1, region, [c::myself.consumed[region][c]+myself.penurie[region][c]]); // send the demands to the producer
			    		// note : in this example, we do not take into account the 'ok' signal.
			    	}
    			}
		    }
    	}
    }
    
	action population_distribution{
		ask agri_distributeur{
			do distribution;
		}
	}
	
	/**
	 * We define here the production agent of the agricultural bloc as a micro-species (equivalent of nested class in Java).
	 * We implement the methods of the API.
	 * The production is very simple here : for each behavior, we apply an average resource consumption and emissions.
	 * Some of those resources can be provided by other blocs (external producers).
	 */
	species agri_producer parent:production_agent{
		map<string, bloc> external_producers; // external producers that provide the needed resources
		map<string, map<string, float>> tick_resources_used <- [];
		// à vérifier et jusitifier si 
		// - resources_used[region][input][output]
		// ou
		// - resources_used[region][input]
		map<string, map<string, float>> tick_surface_used <- [];
		map<string, map<string, float>> tick_surface_manque <- [];
		float tick_surface_used_coton <- 0.0;
		float tick_surface_manque_coton <- 0.0;
		map<string, map<string, float>> tick_production <- [];
		map<string, map<string, map<string, float>>> tick_emissions <- [];
		
		float surface_foret;
		// flag pour gérer la surface (pas encore implémenté)
		bool flag_meat <- false;
		bool flag_vegetables <- false;
		bool flag_coton <- false;
		
		init{
			external_producers <- []; // external producers that provide the needed resources
			// init map
			loop r over: nom_region{
				// resources_used
				tick_resources_used[r] <- [];
				loop i over: production_inputs_A{
					tick_resources_used[r][i] <- 0.0;
				}
				
				// surface_used
				// surface_manque
				// production
				tick_surface_used[r] <- [];
				tick_surface_manque[r] <- [];
				tick_production[r] <- [];
				loop o over: production_outputs_A{
					tick_surface_used[r][o] <- 0.0;
					tick_surface_manque[r][o] <- 0.0;
					tick_production[r][o] <- 0.0;
				}
				tick_surface_used[r]["kg_meat"] <- 0.0;
				tick_surface_manque[r]["kg_meat"] <- 0.0;
				
				// emissions
				tick_emissions[r] <- [];
				loop e over:production_emissions_A{
					tick_emissions[r][e] <- [];
					loop c over: production_outputs_A{
						tick_emissions[r][e][c] <- 0.0;
					}
				}
			}
		}
		
		map<string, map<string, float>> get_tick_inputs_used_region{
			return tick_resources_used;
		}
		
		map<string, map<string, float>> get_tick_outputs_produced_region{
			return tick_production;
		}
		
		map<string, map<string, map<string, float>>> get_tick_emissions_region{
			return tick_emissions;
		}
		
		map<string, map<string, float>> get_tick_surface_used{
			return tick_surface_used;
		}
		
		map<string, map<string, float>> get_tick_surface_manque{
			return tick_surface_manque;
		}
		
		// not used
		////////////////////////////////////////////////////////////////////////////
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
		
		action set_supplier(string product, bloc bloc_agent){
			write name+": external producer "+bloc_agent+" set for "+product;
			external_producers[product] <- bloc_agent;
		}
	
		action reset_tick_counters{ // reset impact counters
			loop r over: nom_region{
				loop u over: production_inputs_A{
					tick_resources_used[r][u] <- 0.0; // reset resources usage
				}
				loop p over: production_outputs_A{
					tick_production[r][p] <- 0.0; // reset productions
					tick_surface_used[r][p] <- 0.0; // reset surface used
					tick_surface_manque[r][p] <- 0.0; // reset surface manque
				}
				tick_surface_used[r]["kg_meat"] <- 0.0;
				tick_surface_manque[r]["kg_meat"] <- 0.0;
				loop e over: production_emissions_A{
					loop p over: production_outputs_A{
						tick_emissions[r][e][p] <- 0.0; // reset emission par output
					}
				}
			}
			tick_surface_used_coton <- 0.0;
			tick_surface_manque_coton <- 0.0;

			// reset flag
			flag_meat <- false;
			flag_vegetables <- false;
			flag_coton <- false;
		}
		
		bool produce(int id, string region, map<string,float> demand){
			// write("\n[Agri] dans produce");
			// write("[Agri] demand : "+demand);
			bool ok <- true;
			loop c over: demand.keys{
				loop u over: production_inputs_A{
					// write("[Agri] c : "+c);
					// write("[Agri] u : "+u);
					// write("[Agri] production_output_inputs_A[c][u] : "+production_output_inputs_A[c][u]);
					// write("[Agri] demand[c] : "+demand[c]);
					float quantity_needed <- production_output_inputs_A[c][u] * demand[c]; // quantify the resources consumed/emitted by this demand
					// check si production externe
					if(external_producers.keys contains u){ // if there is a known external producer for this product/good
						bool av <- external_producers[u].producer.produce(id, region, [u::quantity_needed]); // ask the external producer to product the required quantity
						if not av{
							ok <- false;
						}
						tick_resources_used[region][u] <- tick_resources_used[region][u] + quantity_needed;
					}	
					// sinon
					else{
						// gestion surface agricole
						if(u = "m² land"){
							// si manque de surface
							
							ok <- false;
							if(c = "kg_bovine" or c = "kg_porc" or c = "kg_poulet"){
								// si surface non suffisante pour la ferme
								if(tick_surface_used[region]["kg_meat"] + quantity_needed > espace_ferme[region]){
									if not flag_meat{
										write("manque de surface pour la ferme dans la région "+region+" !");	
										flag_meat <- true;
										// tick_resources_used[u] <- tick_resources_used[u] + espace_ferme - tick_surface_used[c];
										tick_surface_manque[region]["kg_meat"] <- tick_surface_used[region]["kg_meat"] + quantity_needed - espace_ferme[region];
										tick_surface_used[region]["kg_meat"] <- espace_ferme[region];
									}
									else{
										tick_surface_manque[region]["kg_meat"] <- tick_surface_manque[region]["kg_meat"] + quantity_needed;
									}
								}
								// sinon surface suffisante
								else{
									tick_surface_used[region]["kg_meat"] <- tick_surface_used[region]["kg_meat"] + quantity_needed;
								}
							}
							else if(c = "kg_vegetables"){
								// si surface non suffisante pour les légumes
								if(tick_surface_used[region][c] + quantity_needed > espace_legumes[region]){
									if not flag_vegetables{
										write("manque de surface pour les légumes dans la région "+region+" !");	
										flag_vegetables <- true;
										tick_surface_manque[region][c] <- tick_surface_used[region][c] + quantity_needed - espace_legumes[region];
										tick_surface_used[region][c] <- espace_legumes[region];
									}
									else{
										tick_surface_manque[region][c] <- tick_surface_manque[region][c] + quantity_needed;
									}
								}
								// sinon surface suffisante
								else{
									tick_surface_used[region][c] <- tick_surface_used[region][c] + quantity_needed;
								}
									
							}
							else if(c = "kg_coton"){
								if(tick_surface_used_coton + quantity_needed > espace_coton){
									if not flag_coton{
										write("manque de surface pour le coton!");	
										flag_coton <- true;
										tick_surface_manque_coton <- tick_surface_used_coton + quantity_needed - espace_coton;
										tick_surface_used_coton <- espace_coton;
									}
									else{
										tick_surface_manque_coton <- tick_surface_manque_coton + quantity_needed;
									}
								}
								else{
									tick_surface_used_coton <- tick_surface_used_coton + quantity_needed;
								}
									
							}
							else{
								write("demande inconnu : " + c);
							}
							
						}
						else{
							write("input inconnu : "+u);
						}	
					}
				}		
				
				loop e over: production_emissions_A{ // apply emissions
					float quantity_emitted <- production_output_emissions_A[c][e] * demand[c];
					tick_emissions[region][e][c] <- tick_emissions[region][e][c] + quantity_emitted;
				}
				tick_production[region][c] <- tick_production[region][c] + demand[c];
			}
			return ok;
		}
	}
	
	/**
	 * We define here the consumption agent of the agricultural bloc as a micro-species (equivalent of nested class in Java).
	 * We implement the methods of the API.
	 * The consumption is very simple here : each behavior as a certain probability to be selected.
	 */
	species agri_consumer parent:consumption_agent{
		// stock/consommation/pénurie au sein des régions
		map<string, map<string, float>> consumed <- [];
		map<string, map<string, float>> stocked <- [];
		map<string, map<string, float>> penurie <- [];
		
		map<string, map<string, float>> get_tick_consumption_region{
			return copy(consumed);
		}
		
		map<string, map<int, map<string, float>>> get_tick_consumption_mv{
			// not used
			map<string, map<int, map<string, float>>> tmp <- []; 
			return tmp;
		}
		
		map<string, map<string, float>> get_tick_stock{
			return copy(stocked);
		}
		
		map<string, map<string, float>> get_tick_penurie{
			return copy(penurie);
		}
		
		action set_stock(map<string, map<string, float>> producted){
			loop region over: nom_region{
				loop c over: indivudual_consumption_A.keys{
					stocked[region][c] <- stocked[region][c]+producted[region][c];
				}
			}
		}
		
		action set_distribution(map<string, map<string, float>> s, map<string, map<string, float>> p){
			stocked <- s;
			penurie <- p;
		}
		
		init{
			loop region over: nom_region{
				consumed[region] <- [];
				stocked[region] <- [];
				penurie[region] <- [];
				loop c over: production_outputs_A{
					consumed[region][c] <- 0;
					stocked[region][c] <- 0;
					penurie[region][c] <- 0;
				}
			}
			write("[Agri] init consumed : "+consumed);
		}
		
		action reset_tick_counters{ 
			loop r over: nom_region{
				loop c over: consumed[r].keys{ // reset choices counters
					consumed[r][c] <- 0;
	    		}
			}
		}
		
		action consume(miniville mv){
			string r <- mv.region;
			int nb_pop <- mv.nb_population;
			// write("stock before consumption : "+stocked);
			// calcul de la consommation
			// write("[Agri] ind cons leys : "+indivudual_consumption_A.keys);
			loop c over: indivudual_consumption_A.keys{
		    	consumed[r][c] <- consumed[r][c]+(indivudual_consumption_A[c]*nb_pop*echelle);
		    }
		    //write("[Agri] consumed[region] : "+consumed[r]);
		}
		
		action gestion_stock{
			if (cycle>0){
		    	// calcul de stock/pénurie
		    	loop r over: nom_region{
		    		loop c over: indivudual_consumption_A.keys{
				    	if (stocked[r][c] >= consumed[r][c]+penurie[r][c]){
				    		stocked[r][c] <- stocked[r][c]-consumed[r][c]-penurie[r][c];
				    		penurie[r][c] <- 0;
				    	}
				    	else{
				    		penurie[r][c] <- penurie[r][c]+consumed[r][c]-stocked[r][c];
				    		stocked[r][c] <- 0;
				    	}
				    }
		    	}
		    }
		}
	}
	
	species agri_distributeur parent:distribution_agent{
		// stock/consommation/pénurie au sein des régions
		map<string, map<string, float>> stocked <- [];
		map<string, map<string, float>> penurie <- [];
		
		map<string, map<string, float>> distribution <- [];
		map<string, map<string, float>> reception <- [];
		// à voir si intéressant distribution entre quelles regions
		
		map<string, map<string, float>> get_tick_distribution_region{
			return copy(distribution);
		}
		
		map<string, map<string, float>> get_tick_reception_region{
			return copy(reception);
		}
		
		map<string, map<int, map<string, float>>> get_tick_distribution_mv{
			// not used
			map<string, map<int, map<string, float>>> tmp <- []; 
			return tmp;
		}
		
		map<string, map<int, map<string, float>>> get_tick_reception_mv{
			// not used
			map<string, map<int, map<string, float>>> tmp <- []; 
			return tmp;
		}
		
		init{
			loop region over: nom_region{
				distribution[region] <- [];
				reception[region] <- [];
				loop c over: production_outputs_A{
					distribution[region][c] <- 0;
					reception[region][c] <- 0;
				}
			}
		}
		
		action reset_tick_counters{ 
			loop r over: nom_region{
				loop c over: indivudual_consumption_A.keys{ // reset choices counters
	    			distribution[r][c] <- 0;
	    			reception[r][c] <- 0;
	    		}
			}
		}
		
		action distribution{
			ask agri_consumer{
				myself.stocked <- get_tick_stock();
				myself.penurie <- get_tick_penurie();
			}
			// write("[Agri] stocked : "+stocked);
			// write("[Agri] penurie : "+penurie);
	    	// vérifie si un ou plusieurs région sont en pénurie
	    	// s'il existe alors on demande la distribution où il a plus de stock
	    	loop c over: indivudual_consumption_A.keys{
	    		loop dest over: nom_region{
	    			// variable qui sauvegarde de combien en ressource depuis quel region
	    			float max_stock <- 0.0;
	    			string max_stock_region;
	    			bool all_penurie <- false;
	    			if (penurie[dest][c] > 0){
	    				loop while: ((penurie[dest][c] > 0) and (! all_penurie)){
	    					max_stock <- 0.0;
	    					all_penurie <- true;
	    					loop depart over: nom_region{
		    					if (dest != depart){
		    						if (stocked[depart][c] > max_stock){
		    							max_stock <- stocked[depart][c];
		    							max_stock_region <- depart;
		    							all_penurie <- false;
		    						}
		    					}
		    				}
		    				if (! all_penurie){
		    					write("[Agri] find region distributeur : "+max_stock_region+" -> "+dest+", "+min([penurie[dest][c], max_stock])+"/"+penurie[dest][c]+" "+c);
		    					ask transport{
			    					do ask_transport_externe(max_stock_region, dest, c, min([myself.penurie[dest][c], max_stock]));
			    				}
			    				// distribution de resource, on diminue en pénurie pour le région demandeur et diminue en stock pour le région distributeur
			    				penurie[dest][c] <- penurie[dest][c] - min([penurie[dest][c], max_stock]);
			    				stocked[max_stock_region][c] <- stocked[max_stock_region][c] - min([penurie[dest][c], max_stock]);
			    				distribution[dest][c] <- distribution[dest][c] + min([penurie[dest][c], max_stock]);
			    				reception[max_stock_region][c] <- reception[max_stock_region][c] + min([penurie[dest][c], max_stock]);
		    				}
		    				else{
		    					write("[Agri] no region distributeur pour "+c+" à la région "+dest);
		    				}
	    				}
	    			}
	    			if (all_penurie){
				    	break;
				    }
			    }
	    	}
	    	ask agri_consumer{
	    		do set_distribution(stocked, penurie);
	    	}
	    }
	}
}

/**
 * We define here the experiment and the displays related to agricultural. 
 * We will then be able to run this experiment from the Main code of the simulation, with all the blocs connected.
 * 
 * Note : experiment car inherit another experiment, but we can't combine displays from multiple experiments at the same time. 
 * If needed, a new experiment combining all those displays should be added, for example in the Main code of the simulation.
 */
experiment run_agricultural type: gui {
	output {
		display Agricultural_information {
			chart "Population direct consumption" type: series  size: {0.5,0.5} position: {0, 0} {
			    loop c over: production_outputs_A{
			    	data c value: cycle>0 ? tick_consumption_A["Auvergne-Rhône-Alpes"][c] : 0; // note : products consumed by other blocs NOT included here (only population direct consumption)
			    }
			}
			chart "Total production" type: series  size: {0.5,0.5} position: {0.5, 0} {
			    loop c over: production_outputs_A{
			    	data c value: cycle>0 ? tick_production_A["Auvergne-Rhône-Alpes"][c] : 0;
			    }
			}
			/* 
			chart "Usage surface agricole" type: series size: {0.5,0.25} position: {0, 0.25} {
			    loop c over: production_outputs_A{
			    	data c value: cycle>0 ? tick_surface_used_A["Auvergne-Rhône-Alpes"][c] : 0;
			    }
			}
			
			chart "Manque surface agricole" type: series size: {0.5,0.25} position: {0.5, 0.25} {
			    loop c over: production_outputs_A{
			    	data c value: cycle>0 ? tick_surface_manque_A["Auvergne-Rhône-Alpes"][c] : 0;
			    }
			}
			
			chart "Production emissions" type: series size: {0.5,0.25} position: {0, 0.5} {
			    loop e over: production_outputs_A{
			    	data e value: cycle>0 ? tick_emissions_A["Auvergne-Rhône-Alpes"]["gCO2e emissions"][e] : 0;
			    }
			}
			
			chart "Ressources used" type: series size: {0.5,0.25} position: {0.5, 0.5} {
			    loop r over: production_inputs_A{
			    	data r value: cycle>0 ? tick_resources_used_A["Auvergne-Rhône-Alpes"][r] : 0;
			    }
			}
			*/
			chart "Pénurie" type: series size: {0.5,0.5} position: {0 ,0.5} {
				loop c over: production_outputs_A{
					data c value: cycle>0 ? tick_penurie_A["Auvergne-Rhône-Alpes"][c] : 0;
				}
			}
			
			chart "Stock" type: series size: {0.5,0.5} position: {0.5, 0.5} {
			    loop e over: production_outputs_A{
			    	data e value: cycle>0 ? tick_stock_A["Auvergne-Rhône-Alpes"][e] : 0;
			    }
			}
	    }
	}
}