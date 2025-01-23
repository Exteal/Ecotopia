/**
* Name: Energy bloc (MOSIMA)
* Authors: Maël Franceschetti, Cédric Herpson, Jean-Daniel Kant, Imane HADBI, Khaoula ALAYAR
* Mail: firstname.lastname@lip6.fr
*/

model Energy

import "../API/API.gaml"
import "Ecosystem.gaml"
import "InfoRegion.gaml"

/**
 * We define here the global variables and data of the bloc. Some are needed for the displays (charts, series...).
 */
global{
	// the unity used for quantity of energy is Kwh
	/* Setup */
	list production_inputs_E <- ["L water", "m² land"];
	list production_outputs_E <- ["any_energy", "hydro_energy", "nuclear_energy", "solar_energy", "wind_energy"];
	list production_emissions_E <- ["gCO2e emissions"];
	
	/* Production data */	
	map production_output_inputs_E <- [
    "hydro_energy"::["L water"::0.5, "m² land"::0.18],
    "nuclear_energy"::["L water"::5.0, "m² land"::0.005], 
    "solar_energy"::["L water"::0.3, "m² land"::0.16], 
    "wind_energy"::["L water"::0.5, "m² land"::0.02] 
	];
	
	map production_output_emissions_E <- [
	    "hydro_energy"::["gCO2e emissions"::24.0], 
	    "nuclear_energy"::["gCO2e emissions"::12.0], 
	    "solar_energy"::["gCO2e emissions"::45.0], 
	    "wind_energy"::["gCO2e emissions"::11.0] 
	];
	
	/* les pourcentages de chaque type d'énergie pour produire une quantité d'énergie de type non spécifié */
	map percents_mixture_energy <-[
		"coeff hydro_energy"::0.15, 
	    "coeff nuclear_energy"::0.4, 
	    "coeff solar_energy"::0.25, 
	    "coeff wind_energy"::0.2 
	];

// 
	float min_kWh_conso <- 165.0 ;
	float max_kWh_conso <- 205.0; 	
	
	float conso_urbanisme <- 90277778; // estimation conso par region (secteur urbanisme) 13Twh/an
	
	map total_land_used_E <- [
	    "hydro_energy"::0.0,
	    "nuclear_energy"::0.0, 
	    "solar_energy"::0.0, 
	    "wind_energy"::0.0 
	];
	
	map<string,map<string,float>> total_land_used_Region_E <- []; // la surface totale consommée selon le type d'énergie dans une région							
	
	// Le pourcentage de terrain occupé par l'énergie parmi la surface totale des régions
	float percent_Total_land_E <- 0.1;
	
	// à supprimer
	float surface_land_E <- 2.211e+10;
	
	// produire 2.3 de l'énergie demandée pour tenir compte des pertes d'énergie dûes au transport et autre
	float coeff_production<- 2.3;  
	float mix_variation <- 0.05; 
			
	/* Counters & Stats */
	map<string,map<string, float>> tick_production_Region_E <- [];
	map<string,map<string, float>> tick_pop_consumption_Region_E <- [];
	map<string,map<string, float>> tick_resources_used_Region_E <- [];
	map<string, map<string, map<string, float>>> tick_emissions_Region_E <- [];
	map<string,map<string, float>> tick_land_used_Region_E <- [];
	map<string,map<string, float>> tick_water_used_Region_E <- [];
	map<string,map<string, float>> tick_to_produce_Region_E <-[];
	map<string, float> tick_penurie_National_E <- [];  
	map<string,map<string, float>> tick_penurie_Regional_E <- [];
	map<string, float> tick_total_consumption_National_E <- [];
	
	
	init{ 
		// a security added to avoid launching an experiment without the other blocs
		if (length(coordinator) = 0){
			error "Coordinator agent not found. Ensure you launched the experiment from the Main model";
			// If you see this error when trying to run an experiment, this means the coordinator agent does not exist.
			// Ensure you launched the experiment from the Main model (and not from the bloc model containing the experiment).
		}
		loop r over: nom_region{
			tick_production_Region_E[r] <-[];
			tick_pop_consumption_Region_E[r]<- [];
			tick_resources_used_Region_E[r] <-[];
			tick_emissions_Region_E[r] <-[];
			loop e over:production_emissions_E{
				tick_emissions_Region_E[r][e] <- [];
			}
			tick_land_used_Region_E[r] <- [];
			tick_water_used_Region_E[r] <- [];
			tick_to_produce_Region_E[r] <- [];
			tick_penurie_Regional_E[r] <- [];
			
		}
	}
	
}

/**
 * We define here the agricultural bloc as a species.
 * We implement the methods of the API.
 * This bloc is very minimalistic : it only apply an average consumption for the population, and provide energy to other blocs.
 */
species energy parent:bloc{
	string name <- "energy";
	
	energy_producer producer <- nil;
	energy_consumer consumer <- nil;
	
	   
	action setup{
		list<energy_producer> producers <- [];  
		list<energy_consumer> consumers <- [];  
		create energy_producer number:1 returns:producers; // instanciate the energy production handler
		create energy_consumer number:1 returns:consumers; // instanciate the energy consumption handler
		producer <- first(producers);
		consumer <- first(consumers);
	}
	
		
	action tick_consumer(list<miniville> mv) {
		do collect_last_tick_data();  // TODO: à vérifier
		do population_consumption(mv);
	}
	
	action tick_producer {
		do population_production;
		
	}
	action tick_distribution{

	}
	
	action set_external_producer(string product, bloc bloc_agent){
		ask producer{
			do set_supplier(product, bloc_agent);
	    }
	}

	production_agent get_producer{
		//write "producer inside target bloc : "+producer;
		return producer;
	}
	
	list<string> get_output_resources_labels{
		return production_outputs_E;
	}
	
	list<string> get_input_resources_labels{
		return production_inputs_E;
	}
	
	list<string> get_emissions_labels{
		return production_emissions_E;
	}

	
	// collecter les datas du tick précedent 
	action collect_last_tick_data{
		
		if(cycle > 0){ // skip it the first tick
			tick_pop_consumption_Region_E <- consumer.get_tick_consumption_region(); // collect consumption behaviors
			tick_total_consumption_National_E <- producer.get_tick_total_consumption(); // consommation nationale par type d'énergie
    		tick_resources_used_Region_E <- producer.get_tick_inputs_used_region(); // collect resources used
	    	tick_production_Region_E <- producer.get_tick_outputs_produced_region(); // collect production
	    	tick_emissions_Region_E <- producer.get_tick_emissions(); // collect emissions
	    	tick_land_used_Region_E <- producer.get_tick_land_used_Region();  // collect land used by each type of energy
	    	tick_water_used_Region_E <- producer.get_tick_water_used_Region();  // collect water used by each type of energy
    		tick_penurie_Regional_E <- producer.get_tick_penurie_Region();
    		
	    	ask energy_consumer{ // prepare next tick on consumer side
	    		do reset_tick_counters; 
	    	}
	    	
	    	ask energy_producer{ // prepare next tick on producer side
	    		do reset_tick_counters; 
	    	}
	    	
    	}
	}
	
	
	
    	
	action population_consumption(list<miniville> Lmv) {
    	ask Lmv{  
    		ask myself.energy_consumer{
    			do consume(myself);
    		}
    	}
    }
    
    action population_production {
    	ask energy_producer{
    		loop region over: nom_region{
    			int id <- 0; // fixé à 0 symboliquement, car id n'est pas utilisé par le bloc d'énergie
				bool ok <- produce(id, region, tick_pop_consumption_Region_E[region]);
			}
		}
    }
	

	/**
	 * We define here the production agent of the energy bloc as a micro-species (equivalent of nested class in Java).
	 * We implement the methods of the API.
	 * The production is minimalistic here : we apply an average resource consumption and emissions for the energy production.
	 */
	species energy_producer parent:production_agent{
		map<string, map<string, float>> tick_resources_used_Region <- [];  // ressources utilisées par region
		map<string, map<string, float>> tick_production_Region <- [];
		map<string, map<string, map<string, float>>> tick_emissions <- [];
		map<string, map<string, float>> tick_water_Region <- [];
		map<string, map<string, float>> tick_land_Region <- [];
		map<string, bloc> external_producers; // external producers that provide the needed resources
		map<string,map<string, float>> tick_penurie_Region;
		map<string, float> tick_land_penurie_Region;
		map<string, float> total_consumption_E;
		map<string, bool> flags;
		
		init{
			external_producers <- []; // external producers that provide the needed resources
			
			loop r over: nom_region{
				
				
				
				// initialiser la superfecie totale utilisée par region
				total_land_used_Region_E[r]<-[
				    "hydro_energy"::0.0,
				    "nuclear_energy"::0.0, 
				    "solar_energy"::0.0, 
				    "wind_energy"::0.0 
				];
				
				// resources_used per region
				tick_resources_used_Region[r] <- [];
				loop i over: production_inputs_E{
					tick_resources_used_Region[r][i] <- 0.0;
				}
				
				// surface_used
				// production
				tick_land_Region[r] <- [];
				tick_water_Region[r] <- [];
				//tick_surface_manque[r] <- [];
				tick_production_Region[r] <- [];
				loop o over: production_outputs_E{
					tick_land_Region[r][o] <- 0.0;
					tick_water_Region[r][o] <- 0.0;
					//tick_surface_manque[r][o] <- 0.0;
					tick_production_Region[r][o] <- 0.0;
				}
	
				// emissions
				tick_emissions[r] <- [];
				loop e over:production_emissions_E{
					tick_emissions[r][e] <- [];
					loop c over: production_outputs_E{
						tick_emissions[r][e][c] <- 0.0;
					}
				}
				
				tick_penurie_Region[r] <- ["hydro_energy"::0.0,
						    "nuclear_energy"::0.0, 
						    "solar_energy"::0.0, 
						    "wind_energy"::0.0 ];
				tick_land_penurie_Region[r] <- 0.0;
			}
	    	
	    	flags <- ["hydro_energy"::false, 
						    "nuclear_energy"::false, 
						    "solar_energy"::false, 
						    "wind_energy"::false ];
						    
			total_consumption_E <- ["any_energy"::0.0,
							"hydro_energy"::0.0, 
						    "nuclear_energy"::0.0, 
						    "solar_energy"::0.0, 
						    "wind_energy"::0.0 ];
	    	
		}
		map<string, map<string, float>> get_tick_inputs_used_region{
			loop r over:nom_region{
				tick_resources_used_Region[r]["m² land"]<-tick_land_Region[r]["hydro_energy"] + tick_land_Region[r]["nuclear_energy"] + tick_land_Region[r]["solar_energy"] + tick_land_Region[r]["wind_energy"] ;
			}
			//TODO: peut être faire pareil pour l'eau
			return tick_resources_used_Region;
		}
		
		map<string, map<string, float>> get_tick_outputs_produced_region{
			return tick_production_Region;
		}
		
		map<string, map<string, map<string, float>>> get_tick_emissions_region{
			return tick_emissions;
		}
		
		map<string, map<string, map<string, float>>> get_tick_emissions{
			return tick_emissions;
		}
		
		map<string, map<string, float>> get_tick_land_used_Region{
			return tick_land_Region;
		}
		
		map<string, map<string, float>> get_tick_water_used_Region{
			return tick_water_Region;
		}
		
		map<string,map<string, float>> get_tick_penurie_Region{
			return tick_penurie_Region;
		}
		
		map<string, float> get_tick_total_consumption{
			return total_consumption_E;  
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
		
		action set_supplier(string product, bloc bloc_agent){
			//write "in energy bloc, set_supplier";
			external_producers[product] <- bloc_agent;
		}
		
		
		action reset_tick_counters{ // reset impact counters
			
			loop r over: nom_region{
				loop u over: production_inputs_E{
					tick_resources_used_Region[r][u] <- 0.0; // reset resources usage
				}	
			}
			
			loop r over: nom_region{
				loop p over: production_outputs_E{
					tick_production_Region[r][p] <- 0.0; // reset productions
				}
			}
			
//			loop e over: production_emissions_E{
			loop r over: nom_region{
				loop e over: production_emissions_E{
					loop p over: production_outputs_E{
						tick_emissions_Region_E[r][e][p] <- 0.0;
					}	
				}
			}
			
			loop r over: nom_region{
				loop e over: production_outputs_E{
					tick_land_Region[r][e] <- 0.0;
				}
			}
			
			loop r over: nom_region{
				loop e over: production_outputs_E{
					tick_water_Region[r][e] <- 0.0;
				}
			}
			
			loop r over: nom_region{
				loop u over: production_outputs_E{
					tick_penurie_Region[r][u] <- 0.0;
				}	
			}
			loop e over: production_outputs_E{
				tick_penurie_National_E[e] <- 0.0;
			}
			
			loop f over: flags.keys{
				flags[f]<-false;
			}
		}
		bool land_available(float quantity_needed, string r){
			float tmp<-0.0;
			loop t over: total_land_used_Region_E[r].keys{
				tmp <- tmp + total_land_used_Region_E[r][t];
			}
			return tmp + quantity_needed <= superfecie_region[r]*percent_Total_land_E;//TODO: à mettre ici les vraies valeurs de la surface utilisée par la région pour E 
		}
		
		
		bool produce(int id, string region, map<string, float> demand){ // apply the input
			//write"producing";
			//write percents_mixture_energy;
			bool ok <- true;
			bool can_produce_c <- true;
			bool missing_land <- false;
			bool missing_water <- false;
			
			map<string,float> to_produce <- ["hydro_energy"::0.0, "nuclear_energy"::0.0, "solar_energy"::0.0,"wind_energy"::0.0];
			
			// calculer l'énergie à produire pour chaque demande. coeff_production est utilisé car, pour chaque quantité A d'énergie à consommer, il faut produire coeff_production*A, tenant compte des pertes d'énergie.
			loop d over: demand.keys{
				total_consumption_E[d] <- total_consumption_E[d] + demand[d];
				if (d = "any_energy"){
					to_produce["hydro_energy"] <- to_produce["hydro_energy"] + demand[d]*percents_mixture_energy["coeff hydro_energy"]*coeff_production;
					to_produce["nuclear_energy"] <- to_produce["nuclear_energy"] + demand[d]*percents_mixture_energy["coeff nuclear_energy"]*coeff_production;
					to_produce["solar_energy"] <- to_produce["solar_energy"] + demand[d]*percents_mixture_energy["coeff solar_energy"]*coeff_production;
					to_produce["wind_energy"] <- to_produce["wind_energy"] + demand[d]*percents_mixture_energy["coeff wind_energy"]*coeff_production;
				}
				else{
					to_produce[d] <- to_produce[d] + demand[d]*coeff_production;
				}
			}

			// produire les différents type d'énergie
			loop c over: to_produce.keys{   // pour chaque type d'énergie à produire
				if (to_produce[c] != 0.0){
					can_produce_c <- true;
					float quantity_emitted;
	   				loop u over: production_inputs_E{  // pour chaque ressource u necéssaire à produire c
	   					if(can_produce_c = true){  // si jusqu'à maintenant, aucune ressource ne manque (et donc pouvoir produire c), continuer à boucler sur les autres ressources
							float quantity_needed <- production_output_inputs_E[c][u] * to_produce[c];  // quantité dont on a besoin de u pour produie c
							if(u = "m² land"){  // si la ressource est le terrain
								if(total_land_used_Region_E[region][c]<quantity_needed){ // si la surface déjà utilisée dans la région ne suffit pas pour produire la demande : utiliser une surface supp
									float land_supp <- quantity_needed-total_land_used_Region_E[region][c]; // terrain à ajouter pour répondre complétement au besoin
									//write land_supp;
									if(not land_available(land_supp, region)){  // si la surface totale utilisée jusqu'à mtnt par l'énergie dans la région + surface à consomer > surface consacrée à l'énergie
										//write "land not available";
										ok <- false;    // enregistrer que les demandes ne sont pas complètement produites
										can_produce_c <- false; //indiquer que nous ne pouvons pas produire c
										
										// TODO: à remmetre : write("manque de surface pour la production de "+ land_supp +" "+ c+" pour la région "+region);
			 							tick_land_penurie_Region[region] <- land_supp;
			 							
										// à supprimer
										if not flags[c]{ // si ce n'est pas la première fois que nous n'arrivons pas à produire l'énergie c
											//write("manque de surface pour la production de "+ quantity_needed +" "+ c);
											flags[c] <- true;  // indiquer que nous ne pouvons plus produire l'énergie c
										}
									}
									else{
										//write "++ land";
										//tick_resources_used_Region[region][u] <- tick_resources_used_Region[region][u] + (quantity_needed - tick_land_Region[region][c]); // Ajouter la surface de terrain supplémentaire utilisée par la région "region" et le type d'énergie "c" pendant le tick actuel
										tick_land_Region[region][c] <- quantity_needed; //étant donnée que que total_land_used_Region_E ne suffit pas pour le besoin, (TODO: à vérifier) alors tick_land_Region l'est également, donc il faut l'agrandir de sorte qu'elle soit adaptée au besoin "quantity needed", d'où tick_land_Region[region][c] <- quantity_needed
										total_land_used_E[c] <- total_land_used_E[c] + land_supp;
										total_land_used_Region_E[region][c] <- total_land_used_Region_E[region][c] + land_supp;
									}
								}
								else{ // si la surface déjà utilisée dans la région suffit pour produire la demande
									if tick_land_Region[region][c] < quantity_needed{ // si le terrain consommé pendant ce tick ne suffit pas
										//tick_resources_used_Region[region][u] <- tick_resources_used_Region[region][u] + (quantity_needed - tick_land_Region[region][c]);
										tick_land_Region[region][c] <- quantity_needed;
									}
								}				
							}								
							
							if(external_producers.keys contains u){ // if there is a known external producer for this product/good
								bool av <- external_producers[u].producer.produce(id, region, [u::quantity_needed]); // ask the external producer to product the required quantity
								if not av{
									ok <- false;
									can_produce_c <- false; //indiquer que nous ne pouvons pas produire c
									if(u = "L water"){
										if not flags[c]{
											//TODO à remettre: write("insufficient stock of water to produce "+ quantity_needed +" "+ c);
											flags[c] <- true;
										}
									}
								}
								else{
									if(u = "L water"){
										// write "water_is_available "+quantity_needed+" = "+production_output_inputs_E[c][u]+" * "+ to_produce[c];
					            		tick_water_Region[region][c] <- tick_water_Region[region][c] + quantity_needed;  // mettre à jour la quantitée d'eau utilisée par le type d'énergie c
					            		tick_resources_used_Region[region][u] <- tick_resources_used_Region[region][u] + quantity_needed; // mettre à jour la consommation d'eau pendant le tick actuel
									}
								}
							}
						}
					}
					
					
					if (can_produce_c = true){ // s'il n'y a aucun problème de pénurie
						//write"produced";
						//production de l'énergie de type c
						tick_production_Region[region][c] <- tick_production_Region[region][c] + to_produce[c];
						
						// emission de CO2 de chaque type d'énergie 
						loop e over: production_emissions_E{ // apply emissions
							quantity_emitted <- production_output_emissions_E[c][e] * to_produce[c];
							tick_emissions[region][e][c] <- tick_emissions[region][e][c] + quantity_emitted;
						}	
					}	
					else { // Si production non accomplie
						// produire selon les ressources qui restent, et enregistrer la partie non produite en pénurie
						float quantity_needed_land <- production_output_inputs_E[c]["m² land"] * to_produce[c];
						float quantity_needed_water <- production_output_inputs_E[c]["L water"] * to_produce[c];
						float percent_produced_energie;
						float quantity_land_to_add ;
						float percent_production ;
						float quantity_water_to_use ;
						float to_produce2 ;
						bool continue_to_produce <- false;
						
						if (tick_land_penurie_Region[region] > 0.0){ // si manque de terrain
							missing_land <- true;
							//write "********************land needed "+region;
							
							//1 - s'il reste assez d'eau, produire une partie de la demande avec les centrales déjà existantes
							percent_production <- (total_land_used_Region_E[region][c]/quantity_needed_land);
							to_produce2 <- to_produce[c]*percent_production;
							quantity_water_to_use <- quantity_needed_water * percent_production;
							
							bool av <- external_producers["L water"].producer.produce(id, region, ["L water"::quantity_water_to_use]); // ask the external producer to product the required quantity
							if not av{  // pénurie d'eau et de terre
								// import magique en cas de pénurie d'eau
								write "[Energy] manque d'eau 1";
								tick_penurie_Region[region][c] <- tick_penurie_Region[region][c] +to_produce[c];
							}
							else{ 
								tick_land_Region[region][c] <- total_land_used_Region_E[region][c];
								tick_production_Region[region][c] <- tick_production_Region[region][c] + to_produce2;
								tick_penurie_Region[region][c] <- tick_penurie_Region[region][c] +to_produce[c] -to_produce2;
								//ajout les emissions
								loop e over: production_emissions_E{ // apply emissions
									quantity_emitted <- production_output_emissions_E[c][e] * to_produce2;
									tick_emissions[region][e][c] <- tick_emissions[region][e][c] + quantity_emitted;
								}
								continue_to_produce <- true;
								write "[Energie]produce 1 done";
							}
									
							//2 - produire une quantité de la demande en utilisant le terrain vide de la region (même s'il ne suffit pas pour combler la demande en entier)
							// calcul terrain vide dans la région
							float occupied <- 0.0;
							loop t over: total_land_used_Region_E[region].keys{
								occupied <- occupied + total_land_used_Region_E[region][t];
							}
							float free_land <- superfecie_region[region]*percent_Total_land_E - occupied ;
							write "[Energie]"+region+" => free_land : "+free_land;
							if (continue_to_produce and free_land > 0.0){	
								//write "Cas pénurie Land, utiliser un supp de "+free_land+" au lieu de "+ tick_land_penurie_Region[region];
								quantity_land_to_add <- free_land; 
								percent_production <- quantity_land_to_add/quantity_needed_land; // pourcentage de la demande qui sera satisfait
								quantity_water_to_use <- quantity_needed_water * percent_production;
								to_produce2 <- to_produce[c] * percent_production;
								
								// vérifier s'il reste de l'eau
								av <- external_producers["L water"].producer.produce(id, region, ["L water"::quantity_water_to_use]); // ask the external producer to product the required quantity
								if not av{  // pénurie d'eau au niveau national
									// import magique
									write "[Energie]manque d'eau 2";
									continue_to_produce <- false;
								}
								else{
									write "produce 2 done";
									tick_land_Region[region][c] <- tick_land_Region[region][c] + quantity_land_to_add;
									total_land_used_E[c] <- total_land_used_E[c] + quantity_land_to_add;
									total_land_used_Region_E[region][c] <- total_land_used_Region_E[region][c] + quantity_land_to_add;
									tick_production_Region[region][c] <- tick_production_Region[region][c] + to_produce2;
									tick_penurie_Region[region][c] <- tick_penurie_Region[region][c] - to_produce2;
									
									//ajout les emissions
									loop e over: production_emissions_E{ // apply emissions
										quantity_emitted <- production_output_emissions_E[c][e] * to_produce2;
										tick_emissions[region][e][c] <- tick_emissions[region][e][c] + quantity_emitted;
									}
									
									if (tick_land_Region[region][c] = total_land_used_Region_E[region][c]){
										write "[Energie] la pénurie est gérée correctement";
									}
									else{
										write "[Energie] il y a un problème dans la gestion de penurie !";
									}
								}
							}
							
							//3 - réduire la pénurie restante en important depuis les autres régions si possible
							quantity_land_to_add <- quantity_needed_land - tick_land_Region[region][c]; // le terrain necessaire pour produire l'energie qui manque
							percent_production <- quantity_land_to_add/quantity_needed_land; 
							quantity_water_to_use <- quantity_needed_water * percent_production;
							to_produce2 <- to_produce[c] * percent_production;
							
							// chercher la région avec le plus de terrain vide
							bool satisfied <- false;
							string other_region_with_max_free_land;
							float max_free_land <- 0.0;
							if (continue_to_produce){
								loop other_region over:nom_region{
									if (other_region != region and not satisfied){
										// calcul de la superfecie de terrain vide chez "other_region"
										occupied <- 0.0;
										loop t over: total_land_used_Region_E[other_region].keys{
											occupied <- occupied + total_land_used_Region_E[other_region][t];
										}
										free_land <- superfecie_region[other_region]*percent_Total_land_E - occupied ;
										
										if (free_land > max_free_land){
											other_region_with_max_free_land <- other_region;
											max_free_land <- free_land;
										}
									}
								}
							}		
							write "[Energie] max_free_land : "+max_free_land+" quantity_land_to_add : "+quantity_land_to_add;
							if (max_free_land > 0){ // s'il ne reste plus de terrain disponible
								if (max_free_land > quantity_land_to_add){ 
									
									//Vérifier qu'il reste assez d'eau
									av <- external_producers["L water"].producer.produce(id, other_region_with_max_free_land, ["L water"::quantity_water_to_use]); // ask the external producer to product the required quantity
									if not av{  // pénurie d'eau et de terre
										// import magique
										write "[Energie]manque d'eau 3";
										//tick_penurie_Region[region][c] <- tick_penurie_Region[region][c] + to_produce2;
									}
									else{
										write "[Energie]produce 3 done";
										tick_land_Region[other_region_with_max_free_land][c] <- tick_land_Region[other_region_with_max_free_land][c] + quantity_land_to_add;
										total_land_used_E[c] <- total_land_used_E[c] + quantity_land_to_add ;
										total_land_used_Region_E[other_region_with_max_free_land][c] <- total_land_used_Region_E[other_region_with_max_free_land][c]+ quantity_land_to_add;
										
										// la quantité to_produce[c]*(penurie_land/quantity_needed_land) correspond à la quantité de l'energie c produite par le terrain penurie_land
										tick_production_Region[other_region_with_max_free_land][c] <- tick_production_Region[other_region_with_max_free_land][c] + to_produce2;
										//ajout emission	
										loop e over: production_emissions_E{ // apply emissions
											quantity_emitted <- production_output_emissions_E[c][e] * to_produce2;
											tick_emissions[other_region_with_max_free_land][e][c] <- tick_emissions[other_region_with_max_free_land][e][c] + quantity_emitted;
										}
									}  
								}
								else{ // si même la plus grand terrain disponible dans les autres region ne suffit, produire avec, et utiliser l'import magique pour le deficit
									percent_production <- max_free_land/quantity_needed_land; 
									quantity_water_to_use <- quantity_needed_water * percent_production;
									to_produce2 <- to_produce[c] * percent_production;
									
									//Vérifier qu'il reste assez d'eau
									av <- external_producers["L water"].producer.produce(id, other_region_with_max_free_land, ["L water"::quantity_water_to_use]); // ask the external producer to product the required quantity
									if not av{  // pénurie d'eau et de terre
										// import magique
										write "[Energie]manque d'eau 4";
										//tick_penurie_Region[region][c] <- tick_penurie_Region[region][c] + to_produce2;
									}
									else{
										write "[Energie] produce 4 done";
										tick_land_Region[other_region_with_max_free_land][c] <- tick_land_Region[other_region_with_max_free_land][c] + max_free_land;
										total_land_used_E[c] <- total_land_used_E[c] + max_free_land ;
										total_land_used_Region_E[other_region_with_max_free_land][c] <- total_land_used_Region_E[other_region_with_max_free_land][c]+ max_free_land;
										
										// la quantité to_produce[c]*(penurie_land/quantity_needed_land) correspond à la quantité de l'energie c produite par le terrain penurie_land
										//tick_production_Region[other_region_with_max_free_land][c] <- tick_production_Region[other_region_with_max_free_land][c] + to_produce2;
										//ajout emission	
										loop e over: production_emissions_E{ // apply emissions
											quantity_emitted <- production_output_emissions_E[c][e] * to_produce2;
											tick_emissions[other_region_with_max_free_land][e][c] <- tick_emissions[other_region_with_max_free_land][e][c] + quantity_emitted;
										}
									}  
								}
							}
									
						}
						else{ // si ce n'est pas une pénurie de terrain, alors c'est une pénurie d'eau
							//write " ******************* water needed";
							missing_water <- true;
							tick_penurie_Region[region][c] <- tick_penurie_Region[region][c] + to_produce[c];
						}
						//write tick_penurie_Region;
					}
					
				}
			}
  			if (missing_land){
				//write "lllllland  " + region;
				if (percents_mixture_energy["coeff nuclear_energy"] < 0.4){
					percents_mixture_energy["coeff nuclear_energy"] <- percents_mixture_energy["coeff nuclear_energy"] + mix_variation;
					if (percents_mixture_energy["coeff hydro_energy"] > mix_variation){
						percents_mixture_energy["coeff hydro_energy"] <- percents_mixture_energy["coeff hydro_energy"] - mix_variation;				
					}
					else if (percents_mixture_energy["coeff solar_energy"] > mix_variation){
						percents_mixture_energy["coeff solar_energy"] <- percents_mixture_energy["coeff solar_energy"] - mix_variation;
					}
					else {
						percents_mixture_energy["coeff wind_energy"] <- percents_mixture_energy["coeff wind_energy"] - mix_variation;						
					}
				}
			}
			if(missing_water){
				//write "wwwwwwwwater";
				if (percents_mixture_energy["coeff solar_energy"] < 0.25){	
					percents_mixture_energy["coeff solar_energy"] <- percents_mixture_energy["coeff solar_energy"] + mix_variation;			
					if (percents_mixture_energy["coeff nuclear_energy"] > mix_variation){				
						percents_mixture_energy["coeff nuclear_energy"] <- percents_mixture_energy["coeff nuclear_energy"] - mix_variation;
					}
					else if (percents_mixture_energy["coeff hydro_energy"] > mix_variation){
						percents_mixture_energy["coeff hydro_energy"] <- percents_mixture_energy["coeff hydro_energy"] - mix_variation;
					}
					else{
						percents_mixture_energy["coeff wind_energy"] <- percents_mixture_energy["coeff wind_energy"] - mix_variation;
					}
				}				
			}
			if ((not missing_land) and (not missing_water)){
				if (percents_mixture_energy["coeff solar_energy"] > mix_variation){
					percents_mixture_energy["coeff solar_energy"] <- percents_mixture_energy["coeff solar_energy"] - mix_variation;
					percents_mixture_energy["coeff wind_energy"] <- percents_mixture_energy["coeff wind_energy"] + mix_variation;
				}				
				if (percents_mixture_energy["coeff hydro_energy"] > mix_variation){
					percents_mixture_energy["coeff hydro_energy"] <- percents_mixture_energy["coeff hydro_energy"] - mix_variation;
					percents_mixture_energy["coeff wind_energy"] <- percents_mixture_energy["coeff wind_energy"] + mix_variation;						
				}			
			}
						
			return ok;		
		}	
		
		
		
		action set_supplier(string product, bloc bloc_agent){
			external_producers[product] <- bloc_agent;
		}
	}
	
	/**
	 * We define here the conumption agent of the energy bloc as a micro-species (equivalent of nested class in Java).
	 * We implement the methods of the API.
	 * The consumption is minimalistic here : we apply a random energy consumption for everyone.
	 */
	species energy_consumer parent:consumption_agent{
		
		map<string, map<string, float>> consumed <- [];
		map<string, map<string, float>> consumed2 <- [];
		
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
				loop c over: production_outputs_E{
					consumed[r][c] <- 0.0;
				}
			}
		}
		
		action reset_tick_counters{ 
    		loop r over: nom_region{
				loop c over: production_outputs_E{ // reset choices counters
	    			consumed[r][c] <- 0;
	    		}
			}
		}
		
		action consume(miniville mv){  //TODO: implémentation dépend de la façon dont la population et les minivilles sont implémentés
			string r <- mv.region;
			
			// calcul de la consommation
			string choice <- "any_energy";  //one_of(production_outputs_E);  
			consumed[r][choice] <- consumed[r][choice]+rnd(min_kWh_conso, max_kWh_conso) * mv.nb_population * echelle + conso_urbanisme;
		}
		
	}
}

/**
 * We define here the experiment and the displays related to energy. 
 * We will then be able to run this experiment from the Main code of the simulation, with all the blocs connected.
 * 
 * Note : experiment car inherit another experiment, but we can't combine displays from multiple experiments at the same time. 
 * If needed, a new experiment combining all those displays should be added, for example in the Main code of the simulation.
 */
experiment run_energy type: gui {
	parameter "conso max kwh" var: max_kWh_conso;
	parameter "conso min kwh" var: min_kWh_conso;
    
	output {
		display Energy_information {
			
			chart "Population direct consumption" type: series  size: {0.5,0.3} position: {0, 0} {
				loop r over:nom_region{
				    data r value: tick_pop_consumption_Region_E[r]["any_energy"];    
				}
			}/* 
			chart "Total production" type: series  size: {0.5,0.3} position: {0.5, 0} {
				
			    loop c over: production_outputs_E{
			    	if(c != "any_energy"){
			    		data c value: tick_production_Region_E["Normandie"][c];
		    		}
			    }
			}*/
			/*chart "Resources usage" type: series size: {0.5,0.3} position: {0, 0.3} {
			    loop r over: production_inputs_E{
				 	if(r != "any_energy"){			    	
			    		data r value: tick_resources_used_Region_E[r];
		    		}
			    }
			}*/
			/*chart "Production emissions gCO2 " type: series size: {0.5,0.3} position: {0.5, 0.3} {
			    loop e over: production_outputs_E{
			    	if(e != "any_energy"){			    	
			    		data e value: tick_emissions_Region_E["Normandie"]["gCO2e emissions"][e];			    		
		    		}
			    }
			}
            chart "Water Usage by Energy Type" type: series size: {0.5, 0.3} position: {0, 0.6} {
                loop e over: production_outputs_E {
			    	if(e != "any_energy"){                	
                    	data e value: tick_water_used_Region_E["Normandie"][e]; // Water used per energy type
                	}
                }
            }
            chart "Land Usage by Energy Type" type: series size: {0.5, 0.3} position: {0.5, 0.6} {
                loop e over: total_land_used_E.keys {
     				if(e != "any_energy"){                		    	             	
                    	data e value: total_land_used_E[e]; // Land used per energy type
                	}               	
                }
            }
            chart "Pénurie" type: series size: {0.5,0.3} position: {0,0.3} {
				loop c over: production_outputs_E{
					if(c != "any_energy"){                	
						data c value: tick_penurie_Regional_E["Normandie"][c];
					}
				}
			}*/
	    }
	}
	
	reflex save_csv {
		ask energy{
			loop r over:nom_region{
				float tick_pop_consumption <- 0.0;
				float tick_production <- 0.0;
				float tick_emissions <- 0.0;
				float tick_land_used <- 0.0;
				float tick_water_used <- 0.0;
				float tick_penurie <- 0.0;
				loop c over:production_outputs_E{
					tick_pop_consumption <- tick_pop_consumption + tick_pop_consumption_Region_E[r][c];
			        tick_production <- tick_production + tick_production_Region_E[r][c];
			        tick_emissions <- tick_emissions + tick_emissions_Region_E[r]['gCO2e emissions'][c];
			        tick_land_used <- tick_land_used + tick_land_used_Region_E[r][c];
			        tick_water_used <- tick_water_used + tick_water_used_Region_E[r][c];
			        tick_penurie <- tick_penurie + tick_penurie_Regional_E[r][c];
				}
			    save [
			    	tick_pop_consumption,
			        tick_production,
			        tick_emissions,
			        tick_land_used,
			        tick_water_used,
			        tick_penurie
			    ] to: "Energy_csv/"+ r + ".csv" rewrite: (cycle = 0) ? true : false header: true;
			}		    
	    }
	}
		
	/*
	reflex save_csv{
    	ask energy{
    		save [tick_production_E["hydro_energy"], tick_production_E["nuclear_energy"], tick_production_E["solar_energy"],tick_production_E["wind_energy"],
    			tick_total_consumption_National_E["any_energy"],tick_total_consumption_National_E["hydro_energy"],tick_total_consumption_National_E["nuclear_energy"],tick_total_consumption_National_E["solar_energy"],tick_total_consumption_National_E["wind_energy"],
    			tick_pop_consumption_E["any_energy"], 
    			tick_resources_used_Region_E["L water"], tick_resources_used_Region_E["m² land"],
    			tick_emissions_Region_E["hydro_energy"],tick_emissions_Region_E["nuclear_energy"],tick_emissions_Region_E["solar_energy"],tick_emissions_Region_E["wind_energy"],
    			tick_penurie_E["hydro_energy"],tick_penurie_E["nuclear_energy"],tick_penurie_E["solar_energy"],tick_penurie_E["wind_energy"]
    		] to:"data_energy_plot.csv" rewrite: (cycle = 0) ? true : false header: true ;
    	}
    }*/
}