/**
* Name: Urbanisme bloc (MOSIMA)
* Authors: Maël Franceschetti, Cédric Herpson, Jean-Daniel Kant
* Mail: firstname.lastname@lip6.fr
*/

model Urbanisme

import "../API/API.gaml"
//import "Ecosystem.gaml"
import "InfoRegion.gaml"

/**
 * Global variables for the Urbanisme block.
 */
global{

	/* ======== STATIC VALUES ======== */

    /* Setup */
    list<string> production_outputs_U <- ["wood building", "modular house"];
    list<string> production_inputs_U <- ["kg_bois", "kg_coton", "m² land", "any_energy"];
    list<string> production_emissions_U <- ["gCO2e emissions"];

    /* -- Production data -- */
	// energy en kWh
	map<string, map<string, float>> production_output_inputs_U <- [	
		"wood building"::["kg_bois"::19350.7, "kg_coton"::0.0, "m² land"::250.0, "any_energy"::12500.0],
		"modular house"::["kg_bois"::0.0, "kg_coton"::27000.0, "m² land"::70.0, "any_energy"::3360.0]
	];    
	
	map<string, map<string, float>> production_output_emissions_U <- [
		"wood building"::["gCO2e emissions"::36000.0],
		"modular house"::["gCO2e emissions"::10080.0]
	];
	/* --------------------- */
	
    // Housing capacities
	map<string, int> housing_capacities <- ["wood building"::45, "modular house"::12, "camp"::25];

    // Repartition ratios
    map<string, float> repartition <- ["wood building"::0.6, "modular house"::0.4];

	// Zone allocation
	map<string, float> zone_allocation <- ["housing"::0.4, "work"::0.3, "education"::0.1, "leisure"::0.2];
	float total_surface <- 10000.0; // Surface area in m²
	
	// Housing lifespan
	map<string, int> housing_lifespan <- [
	    "wood building"::900,  // (in ticks) => 75 years
	    "modular house"::420   // (in ticks) => 35 years
	];
	
	/* ======== ====== ====== ======== */
	
	
	
	/* ======== DYNAMIC VALUES ======= */
	
    /* ------ Counters & Stats ------ */
    
    /* .... Per Region .... */
    map<string, map<string, float>> tick_region_consumption_U <- [];
    
    map<string, map<string, float>> tick_region_production_U <- [];
    map<string, map<string, float>> tick_region_shortages_U <- [];
	map<string, map<string, float>> tick_region_resources_used_U <- [];
	map<string, map<string, map<string, float>>> tick_region_emissions_U <- [];
	/* .................... */
	
	/* .. Per mini-ville .. */
	map<string, map<int, map<string, float>>> tick_mv_consumption_U <- [];
	
	map<string, map<int, map<string, float>>> tick_mv_production_U <- [];
	map<string, map<int, map<string, float>>> tick_mv_shortages_U <- [];
	map<string, map<int, map<string, float>>> tick_mv_resources_used_U <- [];
	map<string, map<int, map<string, map<string, float>>>> tick_mv_emissions_U <- [];
	/* ................... */

//	map<string, map<string, float>> tick_stock_U <- [];

//  float tick_production_wood_building;
//	float tick_production_modular_house;
//	
//	float tick_consommation_wood_building;
//	float tick_consommation_modular_house;
//	
//	float tick_emission_wood_building;
//	float tick_emission_modular_house;
//	
//	float tick_penurie_wood_building;
//	float tick_penurie_modular_house;
	
//	float tick_stock_wood_building;
//	float tick_stock_modular_house;
	
	map<string, int> global_tick_production <- ["wood building"::0, "modular house"::0];
	map<string, float> global_tick_resources_usage <- ["kg_bois"::0, "kg_coton"::0, "m² land"::0, "any_energy"::0];
	map<string, float> global_tick_emissions <- ["gCO2e emissions"::0];
	
    // Housing counters
//	map<string,int> total_houses <- ["wood building"::134, "modular house"::332];

	map<string, int> total_houses_used <- ["wood building"::0, "modular house"::0, "camp"::0];
	
	/* The 'int' key is the id of the house.
	 * The inner map's keys should be:
	 * - type ("wood building" or "modular house")
	 * - age (int)
	 * - occupied (int)
	 */
	map<int, map<string, string>> housing_registry <- [];
	
	/* ======== ====== ====== ======== */
	
    init{ // a security added to avoid launching an experiment without the other blocs
		if (length(coordinator) = 0){
			error "Coordinator agent not found. Ensure you launched the experiment from the Main model";
			// If you see this error when trying to run an experiment, this means the coordinator agent does not exist.
			// Ensure you launched the experiment from the Main model (and not from the bloc model containing the experiment).
		}
	}
	
}


/**
 * We define here the urbanisme bloc as a species.
 * We implement the methods of the API.
 * We also add methods specific to this bloc to consumption behavior of the population.
 */
species urbanisme parent:bloc{

	string name <- "urbanisme";
	
	urbanisme_producer producer <- nil;
	urbanisme_consumer consumer <- nil;
	
	action setup{
		//list<urbanisme_producer> producers <- [];
		//list<urbanisme_consumer> consumers <- [];
		create urbanisme_producer number:1 returns:producers; // instanciate the urbanism production handler
		create urbanisme_consumer number:1 returns:consumers; // instanciate the urbanism consumption handler
		producer <- first(producers);
		consumer <- first(consumers);
	}
	
	action tick_consumer(list<miniville> mv) {
		do collect_last_tick_data();
		do population_consumption(mv);
	}
	
	action tick_distribution {}
	
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
		return production_outputs_U;
	}
	
	list<string> get_input_resources_labels{
		return production_inputs_U;
	}
	
	list<string> get_emissions_labels{
		return production_emissions_U;
	}
	
	action collect_last_tick_data{
		if(cycle > 0){ // skip if the first tick
			tick_region_consumption_U <- consumer.get_tick_consumption_region(); // collect consumption behaviors per region
			
			tick_region_production_U <- producer.get_tick_outputs_produced_region(); // collect production behaviors per region
			tick_region_shortages_U <- producer.get_tick_shortages_region(); // collect shortages per region
			tick_region_resources_used_U <- producer.get_tick_inputs_used_region(); // collect resources used per region
			tick_region_emissions_U <- producer.get_tick_emissions_region(); // collect emissions per region
			
			
			tick_mv_consumption_U <- consumer.get_tick_consumption_mv(); // collect consumption per mv
	    	
	    	tick_mv_production_U <- producer.get_tick_outputs_produced_mv(); // collect production per mv
	    	tick_mv_shortages_U <- producer.get_tick_shortages_mv(); // collect shortages per mv
	    	tick_mv_resources_used_U <- producer.get_tick_inputs_used_mv(); // collect resources used per mv
	    	tick_mv_emissions_U <- producer.get_tick_emissions_mv(); // collect emissions per region
	    	
//    		tick_stock_U <- consumer.get_tick_stock();	// collect stock

//	    	ask urbanisme_consumer{
//    			do set_stock(tick_production_U);
//    		}
    			
//    		tick_production_wood_building <- tick_production_U["wood building"];
//    		tick_production_modular_house <- tick_production_U["modular house"];
//    		
//    		tick_consommation_wood_building <- tick_pop_consumption_U["wood building"];
//    		tick_consommation_modular_house <- tick_pop_consumption_U["modular house"];
//    		
//    		tick_penurie_wood_building <- 0.0;
//    		tick_penurie_modular_house <- 0.0;
    		
//    		tick_stock_wood_building <- tick_stock_U["wood building"];
//    		tick_stock_modular_house <- tick_stock_U["modular house"];
    		
	    	ask urbanisme_consumer{ // prepare new tick on consumer side
	    		do reset_tick_counters;
	    	}
	    	
	    	ask urbanisme_producer{ // prepare new tick on producer side
	    		do reset_tick_counters;
	    	}
    	}
	}
    
    action population_consumption(list<miniville> mv) {
    	ask mv{
    		ask myself.urbanisme_consumer{
    			do consume(myself);
    		}
    	}
    }
    
    action population_production{    	
    	loop c over: global_tick_production.keys{
		    global_tick_production[c] <- 0;
		}
    	
   		loop c over: global_tick_resources_usage.keys{
		    global_tick_resources_usage[c] <- 0;
		}
		
		loop e over: production_emissions_U{ 
			global_tick_emissions[e] <- 0;
		}
				
    	ask urbanisme_consumer{ // produce the required quantities
    		ask urbanisme_producer{
    			loop region over: nom_region{
    				loop id_mv over: mv_region[region]{
		    			loop c over: myself.consumed.keys{
				    		bool ok <- produce(id_mv, region, [c::myself.consumed[region][id_mv][c]+tick_shortages_mv[region][id_mv][c]]); // send the demands amd the shortages to the producer
				    		// note : in this example, we do not take into account the 'ok' signal.
				    	}
				    }
				}
		    }
    	}
    }
	
	/**
	 * We define here the production agent of the urbanisme bloc as a micro-species (equivalent of nested class in Java).
	 * We implement the methods of the API.
	 * The production is very simple here : for each behavior, we apply an average resource consumption and emissions.
	 * Some of those resources can be provided by other blocs (external producers).
	 */
	species urbanisme_producer parent:production_agent{
		map<string, bloc> external_producers; // external producers that provide the needed resources
//		
//		map<string, map<string, float>> tick_resources_used_region <- [];
//		map<string, map<string, float>> tick_production_region <- [];
//		map<string, map<string, map<string, float>>> tick_emissions_region <- [];
//		
		map<string, map<int, map<string, float>>> tick_resources_used_mv <- [];
		map<string, map<int, map<string, float>>> tick_shortages_mv <- [];
		map<string, map<int, map<string, float>>> tick_production_mv <- [];
		map<string, map<int, map<string, map<string, float>>>> tick_emissions_mv <- [];
	
		init{
			external_producers <- []; // external producers that provide the needed resources
			
			loop region over: nom_region{
//				tick_resources_used_region[region] <- [];
//				loop i over: production_inputs_U{
//					tick_resources_used_region[region][i] <- 0.0;
//				}
//				
//				tick_shortages_region[region] <- [];
//				loop i over: production_outputs_U{
//					tick_shortages_region[region][i] <- 0.0;
//				}
//				
////				tick_surface_used[r] <- [];
//				tick_production_region[region] <- [];
//				loop o over: production_outputs_U{
////					tick_surface_used[r][o] <- 0.0;
//					tick_production_region[region][o] <- 0.0;
//				}
//								
//				tick_emissions_region[region] <- [];
//				loop e over:production_emissions_U{
//					tick_emissions_region[region][e] <- [];
//					loop c over: production_outputs_U{
//						tick_emissions_region[region][e][c] <- 0.0;
//					}
//				}
				
				tick_resources_used_mv[region] <- [];
				tick_shortages_mv[region] <- [];
				tick_production_mv[region] <- [];
				tick_emissions_mv[region] <- [];
				
				loop id_mv over: mv_region[region]{
					tick_resources_used_mv[region][id_mv] <- [];
					loop i over: production_inputs_U{
						tick_resources_used_mv[region][id_mv][i] <- 0.0;
					}
					
					tick_shortages_mv[region][id_mv] <- [];
					loop o over: production_outputs_U{
						tick_shortages_mv[region][id_mv][o] <- 0.0;
					}
					
					tick_production_mv[region][id_mv] <- [];
					loop o over: production_outputs_U{
						tick_production_mv[region][id_mv][o] <- 0.0;
					}
					
					tick_emissions_mv[region][id_mv] <- [];
					loop e over:production_emissions_U{
						tick_emissions_mv[region][id_mv][e] <- [];
						loop c over: production_outputs_U{
							tick_emissions_mv[region][id_mv][e][c] <- 0.0;
						}
					}
				}
			}
		}
		
		map<string, map<string, float>> get_tick_inputs_used_region{
//			return tick_resources_used_region;
			
			map<string, map<string, float>> region_resources_used <- [];

		    loop region_id over: tick_resources_used_mv.keys {
		        map<int, map<string, float>> miniville_data <- copy(tick_resources_used_mv[region_id]);
		        
		        loop miniville_id over: miniville_data.keys {
		            map<string, float> miniville_resources_used <- miniville_data[miniville_id];
		
		            loop building_type over: miniville_resources_used.keys {
		                float resources_used_value <- miniville_resources_used[building_type];
		
		                region_resources_used[region_id][building_type] <- 
		                    region_resources_used[region_id][building_type] + resources_used_value;
		            }
		        }
		    }
		
		    return region_resources_used;
		}
		
		/* Returns the shortages for this tick, per region  */
		map<string, map<string, float>> get_tick_shortages_region{
//			return tick_shortages_region;

			map<string, map<string, float>> region_shortages <- [];

		    loop region_id over: tick_resources_used_mv.keys {
		        map<int, map<string, float>> miniville_data <- copy(tick_production_mv[region_id]);
		        
		        loop miniville_id over: miniville_data.keys {
		            map<string, float> miniville_shortages <- miniville_data[miniville_id];
		
		            loop building_type over: miniville_shortages.keys {
		                float shortage_value <- miniville_shortages[building_type];
						
		                region_shortages[region_id][building_type] <- 
		                    region_shortages[region_id][building_type] + shortage_value;
		            }
		        }
		    }
		
		    return region_shortages;
		}
		
		map<string, map<string, float>> get_tick_outputs_produced_region{
//			return tick_production_region;

			map<string, map<string, float>> region_outputs_produced <- [];

		    loop region_id over: tick_resources_used_mv.keys {
		        map<int, map<string, float>> miniville_data <- copy(tick_production_mv[region_id]);
		        
		        loop miniville_id over: miniville_data.keys {
		            map<string, float> miniville_outputs_produced <- miniville_data[miniville_id];
		
		            loop building_type over: miniville_outputs_produced.keys {
		                float outputs_produced_value <- miniville_outputs_produced[building_type];
		
		                region_outputs_produced[region_id][building_type] <- 
		                    region_outputs_produced[region_id][building_type] + outputs_produced_value;
		            }
		        }
		    }
		
		    return region_outputs_produced;
		}
		
		map<string, map<string, map<string, float>>> get_tick_emissions_region{
//			return tick_emissions_region;

			map<string, map<string, map<string, float>>>  region_emissions <- [];

		    loop region_id over: tick_emissions_mv.keys {
				map<int, map<string, map<string, float>>> miniville_data <- copy(tick_emissions_mv[region_id]);
		        
		        loop miniville_id over: miniville_data.keys {
		            map<string, map<string, float>> miniville_emission_types <- miniville_data[miniville_id];
				    
				    loop emission_type over: miniville_emission_types.keys {
				    	map<string, float> miniville_emissions <- miniville_emission_types[emission_type];
				    	
			            loop building_type over: miniville_emissions.keys {
			                float emissions_value <- miniville_emissions[building_type];
			
			                region_emissions[region_id][emission_type][building_type] <- 
			                    region_emissions[region_id][emission_type][building_type] + emissions_value;
			            }
		            }
		        }
		    }
		
		    return region_emissions;
		}
		
//		map<string, map<string, float>> get_tick_surface_used_region{
//			return tick_surface_used;
//		}
		
		map<string, map<int, map<string, float>>> get_tick_inputs_used_mv{
			return tick_resources_used_mv;
		}
		
		/* Returns the shortages for this tick, per mv  */
		map<string, map<int, map<string, float>>> get_tick_shortages_mv{
			return tick_shortages_mv;
		}
		
		/* Returns the amounts produced this tick, per mv  */
		map<string, map<int, map<string, float>>> get_tick_outputs_produced_mv{
			return tick_production_mv;
		}
		
		/* Returns the amounts emitted this tick, per mv  */
		map<string, map<int, map<string, map<string, float>>>> get_tick_emissions_mv{
			return tick_emissions_mv;
		}
		
		/* Returns the surface used this tick, per mv */
//		map<string, map<int, map<string, float>>> get_tick_surface_used_mv{
//			map<string, map<int, map<string, map<string, float>>>> tmp <- [];
//			return tmp;
//		}
		
		
		action set_supplier(string product, bloc bloc_agent){
			write name+": external producer "+bloc_agent+" set for "+product;
			external_producers[product] <- bloc_agent;
		}
		
		action reset_tick_counters{ // reset impact counters
			loop region over: nom_region{
//				loop u over: production_inputs_U{
//					tick_resources_used_region[region][u] <- 0.0; // reset resources usage
//				}
//				
//				loop p over: production_outputs_U{
//					tick_production_region[region][p] <- 0.0; // reset productions
////					tick_surface_used[r][p] <- 0.0; // reset surface used
//				}
//				
//				loop e over: production_emissions_U{
//					loop p over: production_outputs_U{
//						tick_emissions_region[region][e][p] <- 0.0;
//					}
//				}
				
				loop id_mv over: mv_region[region]{
					loop i over: production_inputs_U{
						tick_resources_used_mv[region][id_mv][i] <- 0.0;
					}
					
					loop o over: production_outputs_U{
						tick_shortages_mv[region][id_mv][o] <- 0.0;
					}
					
					loop o over: production_outputs_U{
						tick_production_mv[region][id_mv][o] <- 0.0;
					}
					
					loop e over:production_emissions_U{
						loop c over: production_outputs_U{
							tick_emissions_mv[region][id_mv][e][c] <- 0.0;
						}
					}
				}
			}
		}
		
		bool produce(int id, string region, map<string, float> demand) {
		    bool ok <- true;
			
		    // Retrieve tick data for the miniville
		    map<string, float> mv_resources_used <- tick_resources_used_mv[region][id];
		    map<string, float> mv_production <- tick_production_mv[region][id];
		    map<string, map<string, float>> mv_emissions <- tick_emissions_mv[region][id];
			
		    // Get the surface allocation for housing in the region
		    map<string, float> region_surface_allocation <- [];//region_surface_data[region];
		    float available_housing_surface <- region_surface_allocation["housing"];
			
		    // Iterate over each type of building in demand
		    loop c over: demand.keys {
		        int required_buildings <- int(demand[c]);
		        int buildings_produced <- 0;
				
		        // Produce buildings while resources and surface allow
		        loop while: buildings_produced < required_buildings {
		            bool can_produce <- true;
					
		            // Check if resources are sufficient
		            loop u over: production_inputs_U {
		                float quantity_needed <- production_output_inputs_U[c][u];
		                
		                // Handle external producers for resources
		                if (external_producers.keys contains u) {
		                    bool resource_available <- external_producers[u].producer.produce(id, region, [u::quantity_needed]);
		                    if not resource_available {
		                        ok <- false;
		                        can_produce <- false;
		                        break;
		                    }
		                } else {
	                        write("[Urbanisme] No producer for " + c);
	                        can_produce <- false;
	                        break;
		                }
		            }
					
//		            // Check surface availability for housing
//		            float surface_needed <- production_output_inputs_U[c]["m² land"];
//		            if (mv_surface_used[region][id]["housing"] + surface_needed > available_housing_surface) {
//		                write("[Urbanisme] Not enough housing surface in " + region + " for " + c);
//		                can_produce <- false;
//		            }
					
		            if not can_produce {
		                break;
		            }
					
		            // Deduct resources
		            loop u over: production_inputs_U {
		                float quantity_needed <- production_output_inputs_U[c][u];
		                mv_resources_used[u] <- mv_resources_used[u] + quantity_needed;
		                global_tick_resources_usage[u] <- global_tick_resources_usage[u] + quantity_needed;
		            }
					
//		            // Deduct housing surface
//		            mv_surface_used[region][id]["housing"] <- mv_surface_used[region][id]["housing"] + surface_needed;
					
		            // Track emissions
		            loop e over: production_emissions_U {
		                float quantity_emitted <- production_output_emissions_U[c][e];
		                mv_emissions[e][c] <- mv_emissions[e][c] + quantity_emitted;
		                global_tick_emissions[e] <- global_tick_emissions[e] + quantity_emitted;
		            }
					
		            // Register new building in the housing registry
		            int new_id <- length(housing_registry) + 1;
		            housing_registry[new_id] <- [
		                "type"::c,
		                "age"::"0",
		                "occupied"::"0"
		            ];
					
		            // Update production counters
		            mv_production[c] <- mv_production[c] + 1;
		            global_tick_production[c] <- global_tick_production[c] + 1;
		
		            buildings_produced <- buildings_produced + 1;
		        }
				
		        // Track shortages if not all buildings were produced
		        if (buildings_produced < required_buildings) {
		            tick_shortages_mv[region][id][c] <- tick_shortages_mv[region][id][c] + (required_buildings - buildings_produced);
		        } else {
		            tick_shortages_mv[region][id][c] <- 0;
		        }
		    }
			
		    // Save updated data for this miniville
		    tick_resources_used_mv[region][id] <- mv_resources_used;
		    tick_production_mv[region][id] <- mv_production;
		    tick_emissions_mv[region][id] <- mv_emissions;
			
		    return ok;
		}
		
	}
	

	/**
	 * We define here the consumption agent of the urbanism bloc as a micro-species (equivalent of nested class in Java).
	 * We implement the methods of the API.
	 * The consumption is very simple here : each behavior as a certain probability to be selected.
	 */
	species urbanisme_consumer parent:consumption_agent{
		/*
		 * - Key: Region id
		 * - Value:
		 * 		- map:
		 * 			- Key: miniville id
		 * 			- Value:
		 * 				- Key: "wood building" or "modular house"
		 * 				- Value: Consumed value 
		 */
		map<string, map<int, map<string, float>>> consumed <- [];
				
		map<string, map<string, float>> get_tick_consumption_region{
			map<string, map<string, float>> region_consumption <- [];

		    loop region_id over: consumed.keys {
		        map<int, map<string, float>> miniville_data <- copy(consumed[region_id]);
		        		
		        // Loop through each miniville in the region
		        loop miniville_id over: miniville_data.keys {
		            map<string, float> miniville_consumption <- miniville_data[miniville_id];
		
		            // Loop through each building type in the miniville's consumption
		            loop building_type over: miniville_consumption.keys {
		                float consumed_value <- miniville_consumption[building_type];
		
		                // Aggregate the consumption value for this building type at the region level
		                region_consumption[region_id][building_type] <- 
		                    region_consumption[region_id][building_type] + consumed_value;
		            }
		        }
		    }
		
		    return region_consumption;
		}
		
		map<string, map<int, map<string, float>>> get_tick_consumption_mv{
			return copy(consumed);
		}
		
		init{
			loop region over: nom_region{
				consumed[region] <- [];
				loop id_mv over: mv_region[region]{
					loop c over: production_outputs_U{
						consumed[region][id_mv][c] <- 0;
					}
				}
			}
		}
		
		action reset_tick_counters{ 
			loop region over: nom_region{
				loop id_mv over: mv_region[region]{
					loop c over: consumed.keys{ // reset choices counters
		    			consumed[region][id_mv][c] <- 0;
		    		}
		   		}
			}
		}
		
		action consume(miniville mv){
			string region <- mv.region;
		    int population <- mv.nb_population;
		    
			consumed[region][mv.id]["wood building"] <- 0;
			consumed[region][mv.id]["modular house"] <- 0;

		    // Calculate currently housed people
		    int currently_housed_people <- 0;
		    loop id over: housing_registry.keys{
		        currently_housed_people <- currently_housed_people + int(housing_registry[id]["occupied"]);
		    }
		    
		    // Calculate currently unhoused people
		    int currently_unhoused_people <- max(0, population - currently_housed_people);
			
			// Assign people to available housing
			loop id over: housing_registry.keys{
		        map<string, string> house <- housing_registry[id];
		        int capacity <- housing_capacities[house["type"]];
		        int occupied <- int(house["occupied"]);
		        
		        // Assign people to this house if there's available capacity
		        if (occupied < capacity) {
		            int available_space <- capacity - occupied;
		            int people_to_assign <- min(available_space, currently_unhoused_people);
		            
		            housing_registry[id]["occupied"] <- (occupied + people_to_assign) as string;
		            
		            currently_unhoused_people <- currently_unhoused_people - people_to_assign;
		
		            if (currently_unhoused_people = 0) {
		                break;
		            }
		        }
		    }
		    
		    total_houses_used["wood building"] <- length(housing_registry where (each["type"] = "wood building")); 
		    total_houses_used["modular house"] <- length(housing_registry where (each["type"] = "modular house")); 
		    
		    // Calculate housing shortages for building requirements
		    float wood_buildings_to_build <- 0.0;
		    float modular_houses_to_build <- 0.0;
			
		    // Handle unhoused people
		    if (currently_unhoused_people > 0) {
		        total_houses_used["camp"] <- ceil(currently_unhoused_people / housing_capacities["camp"]);
		        
		        // Calculate the total current houses and current ratios
			    int total_houses <- total_houses_used["wood building"] + total_houses_used["modular house"];
			
			    float current_wood_ratio <- total_houses > 0 ? (total_houses_used["wood building"] / total_houses) : 0.0;
			    float current_modular_ratio <- total_houses > 0 ? (total_houses_used["modular house"] / total_houses) : 0.0;
				
			    // Target ratios
			    float wood_target_ratio <- repartition["wood building"];
			    float modular_target_ratio <- repartition["modular house"];
			    
			    if (current_wood_ratio < wood_target_ratio) {
			        // Wood buildings are underrepresented
			        wood_buildings_to_build <- ceil((currently_unhoused_people * wood_target_ratio) / housing_capacities["wood building"]);
			        float remaining_unhoused_people <- currently_unhoused_people - (wood_buildings_to_build * housing_capacities["wood building"]);
			        modular_houses_to_build <- remaining_unhoused_people > 0
			            ? ceil((currently_unhoused_people - (wood_buildings_to_build * housing_capacities["wood building"])) / housing_capacities["modular house"])
			            : 0;
			            
			    } else {
			        // Modular houses are underrepresented
			        modular_houses_to_build <- ceil((currently_unhoused_people * modular_target_ratio) / housing_capacities["modular house"]);
			        float remaining_unhoused_people <- currently_unhoused_people - (modular_houses_to_build * housing_capacities["modular house"]);
			        wood_buildings_to_build <- remaining_unhoused_people > 0
			            ? ceil((currently_unhoused_people - (modular_houses_to_build * housing_capacities["modular house"])) / housing_capacities["wood building"])
			            : 0;
			    }
			    
				consumed[region][mv.id]["wood building"] <- wood_buildings_to_build;
				consumed[region][mv.id]["modular house"] <- modular_houses_to_build;
			}
		}
	}

}

/**
 * We define here the experiment and the displays related to urbanism. 
 * We will then be able to run this experiment from the Main code of the simulation, with all the blocs connected.
 * 
 * Note : experiment car inherit another experiment, but we can't combine displays from multiple experiments at the same time. 
 * If needed, a new experiment combining all those displays should be added, for example in the Main code of the simulation.
 */
//experiment run_urbanism type: gui {
//
//	output {
//		display Urbanism_information {
//			chart "Occupied houses" type: series  size: {0.5,1} position: {0, 0} {
//			    loop c over: total_houses_used.keys{
//			    	data c value: tick_pop_consumption_U[c];
//			    }
//			}
//
//
//			chart "Tick construction" type: series  size: {0.5,1} position: {0.5,0} {
//			    loop c over: production_outputs_U{
//			    	data c value: global_tick_production[c];
//			    }
//			}
//	    }
//	    
//	    display Urbanism_resources_emissions {
//			chart "Wood/Cotton usage" type: series size: {0.5,0.5} position: {0, 0} {
//			    loop r over: ["kg_bois", "kg_coton"]{
//			    	data r value: global_tick_resources_usage[r];
//			    }
//			}
//			
//			chart "Land usage" type: series size: {0.5,0.5} position: {0, 0.5} {
//			    data "m² land" value: global_tick_resources_usage["m² land"];
//			    
//			}
//			
//			chart "Energy usage" type: series size: {0.5,0.5} position: {0.5,0} {
//			    data "any_energy" value: global_tick_resources_usage["any_energy"];   
//			}
//			
//			chart "Construction emissions" type: series size: {0.5,0.5} position: {0.5, 0.5} {
//			    loop e over: production_emissions_U{
//			    	data e value: global_tick_emissions[e];
//			    }
//			}
//	    }
//	}
//	
//	reflex save_csv{
//     	ask urbanisme{
//     		save [
//     			global_tick_resources_usage["any_energy"],
//				global_tick_production["wood building"], global_tick_production["modular house"],
//     			global_tick_emissions["gCO2e emissions"],
//				total_houses["wood building"], total_houses["modular house"],
//				total_houses_used["wood building"], total_houses_used["modular house"], total_houses_used["camp"]
//     		] to:"data_urbanisme_plot.csv" rewrite: (cycle = 0) ? true : false header: true ;
//     	}
//    }
//
//}

//TODO: - DONE : Handle shortages (maybe some things should be added to API.gaml ?) : DONE
//TODO: - Handle surface (I think it's handled because it's considered a resource. But who is the producer of this resource? And how is the surface of each miniville specified?
//TODO: - Handle renovations (use housing_registry!!)
//TODO: - Handle 'residence_id' in 'human' species (Or remove it if it's not used)
//TODO: - Handle companies, enternainment centers, universities...
