/**
* Name: Transport
* Based on the internal empty template. 
* Author: doria
* Tags: 
*/


model Transport

/* Insert your model definition here */
import "../API/API.gaml"
import "../blocs/Demography.gaml"
import "StringUtils.gaml"
import "../blocs/InfoRegion.gaml"

global {
	
	/* Regions */
	
	string ile_de_france <- "Île-de-France";
	string auvergne <- "Auvergne-Rhône-Alpes";
	string paca <- "Provence-Alpes-Côte d'Azur";
	string occitanie <- "Occitanie";
	string hauts_de_france <- "Hauts-de-France";
	string aquitaine <- "Nouvelle-Aquitaine";
	string pays_de_la_loire <- "Pays de la Loire";
	string grand_est <- "Grand Est";
	string normandie <- "Normandie";
	string bretagne <- "Bretagne";
	string centre_val_de_loire <- "Centre-Val-de-Loire";
	string bourgogne <- "Bourgogne-Franche-Comté";
	
	
	/* Ville par region */
	string paris <- "paris";
	string rouen <- "rouen";
	
	string tours <- "tours";
	string lille <- "lille";
	
	string strasbourg <- "strasbourg";
	string dijon <- "dijon";
	
	string lyon <- "lyon";
	string toulouse <- "toulouse";
	
	string marseille <- "marseille";
	string bordeaux <- "bordeaux";
	
	string nantes <- "nantes";
	string rennes <- "rennes";
	
	
	/* Correspondances entre regions */
	map<string, string> correspondance_region_vers_ville <- [
		ile_de_france::paris,
		auvergne::lyon,
		paca::marseille,
		occitanie::toulouse,
		hauts_de_france::lille,
		aquitaine::bordeaux,
		pays_de_la_loire::nantes,
		grand_est::strasbourg,
		normandie::rouen,
		bretagne::rennes,
		centre_val_de_loire::tours,
		bourgogne::dijon
	];
	
	
	map<string, map<string, int>> correspondance_ville_vers_voisions <- [
		paris::[rouen::135, tours::241, lille::225, strasbourg::491, dijon::318],
		lille::[rouen::255],
		rouen::[tours::309],
		strasbourg::[lille::552, dijon::333],
		dijon::[tours::424, lyon::195],
		lyon::[toulouse::546, marseille::313, tours::490],
		bordeaux::[toulouse::244, lyon::554, nantes::347, tours::349],
		nantes::[tours::215, rouen::386, rennes::114],
		rennes::[rouen::312],
		toulouse::[marseille::411]
	];
	
	list<string> all_villes <- [
		paris, lyon, marseille, toulouse, 
		lille, bordeaux, nantes, strasbourg, 
		rouen, rennes, tours, dijon
	];
	
	
	/* Graph utils */
	
	map<string, point> correspondance_ville_point <- [];		
	
	/* Types de déplacement */
	
	
	list<string> categories_deplacements <- [loisir, activite];
	list<string> types_deplacement <- [loisir, travail, scolarite, externe];
	list<string> types_deplacements_activite <- [loisir, travail, scolarite];
	
	graph distance_graph;
	
	
	/* Utils déplacements */
	
    float travail_par_mois <- 229 / 12;
    int loisir_par_mois <- 8;
    
    float distance_travail <- 13.3;
    
    float distance_scolarite <- 8.0;
    
    
	map<string, float> distances_loisirs_T <- [domicile::0, espace_naturel::2 , exterieur::5]; 
    
	
    /* Moyens de transport  */	
	string minibus <- "minibus";
	string taxi <- "taxi";
	string pied <- "pied";
	string velo <- "velo";
	string camion <- "camion";
	string train <- "train";
	
	
	int minibus_min_loisir <- 1;
	int taxi_min_loisir <- 3;
	
	
	map transport_par_activite <- [travail::minibus];
    
		
	/* Setup */
	list<string> production_inputs_T <- [any_energy]; //n'utilise que l'électricité
	
	
	/* Production data */

	map<string, map<string,float>> production_output_inputs_T <- []; 

	
	/* Consumption data */

	map<string, float> individual_consumption_T <- [any_energy::0.0]; //consommation de minibus par mois, calculé dessous
		
	// consommation train : http://www.objectifcarbone.org/wp-content/uploads/2024/03/Objectif_Carbone_Note_TDN.pdf -> moyyenne des 2
	
	/* consommation camion :  
	 https://www.construirelawallonie.be/nouvelles/le-poids-lourd-electrique-de-volvo-est-mis-a-rude-epreuve-il-excelle-en-termes-dautonomie-et-defficacite-energetique/
	 https://www.renault-trucks.com/fr/5-idees-recues-sur-les-camions-electriques-0
	
	* assez etrange
	*/
	
	map transports_consumption_T <- [minibus::1.5, taxi::3, pied::0, velo::0, camion::1.1, train::15];
	
	int quantity_threshold_truck <- 25000;
	int distance_threshold_truck <- 250;
	
	
	//https://chargeguru.com/fr/fiches-pratiques/tout-savoir-camions-electriques/
	
	//https://www.captrain.fr/preferez-le-ferroviaire-un-mode-de-transport-pour-la-planete/
	
	map<string,int> capacites_transports_kg <- [camion::6000, train::300000];
		
	/* Counters & Stats */
	
	
	map<string, map<string, float>> tick_production_T <- []; //output de l'agent producteur, même s'il n'a pas de produit
	
	map<string, map<string, float>> tick_pop_consumption_T <- []; // Modèle Macro: conso de toute la population
	
	map<string, map<string, float>> tick_pop_consumption_T_cumulated <- []; //pour chart cumulé
	
	map<string, map<string, float>> tick_resources_used_T <- [];
	map<string, map<string, float>> total_resources_used_T <- [];
	 
	

//	map<string, float> tick_emissions_T <- [];
	map<string, map<string, float>> tick_penurie_T <- []; //trajets inachevés

    
    

	
	init{// a security added to avoid launching an experiment without the other blocs
		if (length(coordinator) = 0){
			error "Coordinator agent not found. Ensure you launched the experiment from the Main model";
			// If you see this error when trying to run an experiment, this means the coordinator agent does not exist.
			// Ensure you launched the experiment from the Main model (and not from the bloc model containing the experiment).
		}
	}
}

/* This bloc is very minimalistic : it only apply an average consumption for the transport of the population.
 */
species transport parent:bloc {
	string name <- "transport"; //nom du bloc
	
	//pointers(?)
	transport_producer producer <- nil;
	transport_consumer consumer <- nil; 
	
	action setup{
		list<transport_producer> producers <- [];
		list<transport_consumer> consumers <- [];
		create transport_producer number:1 returns: producers;
		create transport_consumer number:1 returns: consumers;
		producer <- first(producers);
		consumer <- first(consumers); //un pointeur
		
		distance_graph  <- create_distance_graph();
		
		loop r over: nom_region {
			tick_pop_consumption_T_cumulated[r] <- [];	
			loop j over:types_deplacement {
				tick_pop_consumption_T_cumulated[r][j] <- 0;
			}
		}
		
	}
	
	action tick_consumer(list<miniville> mv) {
		do collect_last_tick_data();
		do population_consumption(mv);
	}
	
	action tick_producer {
		do population_production;
	}
	
	action tick_distribution {
		
	}
	
	graph create_distance_graph {
		
		map<pair<point, point>, int> weights_map;
		
		loop v over: all_villes {		
			point p <- point(rnd(10.0), rnd(10.0));
			correspondance_ville_point[v] <- p;
			
		}
		
		graph distances_graph <- graph([]);
	
		loop v over: all_villes {
			distances_graph <- distances_graph add_node(correspondance_ville_point[v]);
		}
		
		loop ville over: correspondance_ville_vers_voisions.keys {
			loop voisin over: correspondance_ville_vers_voisions[ville].keys {
				graph_edge edge <- graph_edge(correspondance_ville_point[ville]::correspondance_ville_point[voisin]); 
				
				distances_graph <- distances_graph add_edge(correspondance_ville_point[ville]::correspondance_ville_point[voisin]);
				
				int poids <- correspondance_ville_vers_voisions[ville][voisin];
				weights_map[correspondance_ville_point[ville]::correspondance_ville_point[voisin]] <- poids;
			}
		}
		
		
		graph weight_graph <- distances_graph with_weights weights_map;
		return weight_graph;
	}
	
	
	int accumulate_distances(path short) {
		string deb <- nil;
		string fin <- nil;
		int acc <- 0;
				
		loop idx from:0 to: length(short.vertices)-2 {
			loop v over:correspondance_ville_point.keys {
				if (correspondance_ville_point[v] = short.vertices[idx]) {
					deb <- v;
				}
				
				if (correspondance_ville_point[v] = short.vertices[idx+1]) {
					fin <- v;
				}
			}
			
			
			if (deb = nil or fin = nil) {
				write("Bizarre");
				return 0;
			}
			
			int dist;
			try{
				dist <- correspondance_ville_vers_voisions[deb][fin];
			}
			catch{
				dist <- correspondance_ville_vers_voisions[fin][deb];
			}
			acc <- acc + dist;			
		}
		
		return acc;
	
	}
		
	int compute_distance_regions(string region_depart,  string region_dest) {
		path short;
		short <- path_between (distance_graph, correspondance_ville_point[correspondance_region_vers_ville[region_depart]], correspondance_ville_point[correspondance_region_vers_ville[region_dest]]);
		int distance <- accumulate_distances(short);
		return distance;
	}
	
	string transport_choice_externe(int distance_regions, string resource_type, float quantity) {
		if (quantity > quantity_threshold_truck or distance_regions > distance_threshold_truck) {
			return train;
		}
		return camion;
	}
	
	int compute_nb_transports(string transport_type, float quantity) {	
		return int(ceil(quantity /  capacites_transports_kg[transport_type]));
	}
	
	action ask_transport_externe (string region_depart, string region_destination, string resource_type, float quantity) {
		
		int distance_regions <- compute_distance_regions(region_depart, region_destination);		
		string transport_type <- transport_choice_externe(distance_regions, resource_type, quantity);			
		int nb_transports <- compute_nb_transports(transport_type, quantity);
		
		float toAdd <- (transports_consumption_T[transport_type] * distance_regions) * nb_transports;
	
		ask transport_consumer {
			consumed[region_destination][externe] <- consumed[region_destination][externe] + toAdd;	
		}
	}
	
	// ask sector energy for electricity
	action set_external_producer(string product, bloc bloc_agent){
		ask producer{
			do set_supplier(product, bloc_agent);
		}
	}
	transport_producer get_producer{
		return producer;
	}
	list<string> get_output_resources_labels{
		return [];
	}
	list<string> get_input_resources_labels{
		return production_inputs_T;
	}
	
	action collect_last_tick_data{
		if(cycle > 0){ // skip it the first tick
			tick_pop_consumption_T <- consumer.get_tick_consumption_region(); // collect consumption behaviors
			
    		tick_resources_used_T <- producer.get_tick_inputs_used_region(); // collect resources used
	    	tick_production_T <- producer.get_tick_outputs_produced_region();
//			tick_emissions_T <- producer.get_tick_emissions(); // collect emissions
			tick_penurie_T <- producer.get_tick_penurie(); //collecter la pénurie
    	
    			
    		
    		
    		
    		float tick_consumption_loisir_all <- 0;
    		float tick_consumption_travail_all <- 0;
    		float tick_consumption_scolarite_all <- 0;
    		float tick_consumption_externe_all <- 0;
    		    		
    		loop reg over: nom_region {
    			
    			float tick_consumption_loisir <- tick_pop_consumption_T[reg][loisir];
    			float tick_consumption_travail <- tick_pop_consumption_T[reg][travail];
    			float tick_consumption_externe <- tick_pop_consumption_T[reg][externe];
    			float tick_consumption_scolarite <- tick_pop_consumption_T[reg][scolarite];
    			
    			tick_pop_consumption_T_cumulated[reg][loisir] <- tick_pop_consumption_T_cumulated[reg][loisir] + tick_consumption_loisir;
    			tick_pop_consumption_T_cumulated[reg][travail] <- tick_pop_consumption_T_cumulated[reg][travail] + tick_consumption_travail;
    			tick_pop_consumption_T_cumulated[reg][scolarite] <- tick_pop_consumption_T_cumulated[reg][scolarite] + tick_consumption_scolarite;
    			tick_pop_consumption_T_cumulated[reg][externe] <- tick_pop_consumption_T_cumulated[reg][externe] + tick_consumption_externe;

    			tick_consumption_loisir_all <- tick_consumption_loisir_all + tick_consumption_loisir;
    			tick_consumption_travail_all <- tick_consumption_travail_all + tick_consumption_travail;
    			   				
    			tick_consumption_scolarite_all <- tick_consumption_scolarite_all + tick_consumption_scolarite;    				
    			tick_consumption_externe_all <- tick_consumption_externe_all + tick_consumption_externe;    				
    			  				
				save [
					tick_consumption_loisir, tick_consumption_travail, tick_consumption_scolarite, tick_consumption_externe
				] to: "../resultat/transport/data/data_transport_"+reg+".csv" rewrite: cycle>1 ? false : true header: true ;
			    			
    		} 
    		
    		save [
					tick_consumption_loisir_all, tick_consumption_travail_all, tick_consumption_scolarite_all, tick_consumption_externe_all
				] to: "../resultat/transport/data/data_transport_allregions.csv" rewrite: cycle>1 ? false : true header: true ;
				
    		
    		
    		
    		
	    	ask transport_consumer{ // prepare next tick on consumer side
	    		do reset_tick_counters;
	    	}
//	    	total_resources_used_T <- producer.get_tick_inputs_used();
	    	total_resources_used_T <- total_resources_used_T + tick_resources_used_T;
	    	ask transport_producer{ // prepare new tick on producer side
	    		do reset_tick_counters;
	    	}
    	}
	}

    
    action population_consumption(list<miniville> mv) {
    	ask mv {
    		ask myself.transport_consumer {
    			do consume(myself);	
			}	
    	}
    }
    
    
    action population_production{
    	ask transport_consumer{ // produce the required quantities
    		ask transport_producer{
    			loop region over: nom_region {
    				loop c over: myself.consumed.keys{
	    				bool ok <- produce(-1, region, [c::myself.consumed[region][c]]); // send the demands to the producer
			    	}
    			}
		    }
    	}
    }
    
    
	
	species transport_producer parent:production_agent{
		
		map<string, bloc> external_producers; // external producers that provide the needed resources
		map<string, map<string, float>> tick_resources_used <- [];
		map<string, map<string, float>> tick_production <- [];
		map<string, map<string,map<string,  float>>> tick_emissions <- [];

//		map<string, float> tick_emissions <- [];
		map<string, map<string, float>> tick_penurie;
		
		init{
			external_producers <- []; // external producers that provide the needed resources
			
			loop reg over:nom_region {
				tick_resources_used[reg] <- [];
				tick_production[reg] <- [];
				tick_emissions[reg]<- [];
				tick_penurie[reg] <- [];
				
			    loop in over: production_inputs_T {
			    	tick_resources_used[reg][in] <- 0;
			    }
			    
			    loop cons over: transports_consumption_T.keys {
			    	tick_penurie[reg][cons] <- 0;
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
		
		map<string, map<string, float>> get_tick_penurie{
			return tick_penurie;
		}	
		action set_supplier(string product, bloc bloc_agent){
			write name+": external producer "+bloc_agent+" set for "+product;
			external_producers[product] <- bloc_agent;
		}
			
		action reset_tick_counters{ // reset impact counters
			loop r over: nom_region {
				loop u over: production_inputs_T{
					tick_pop_consumption_T[r][u] <- 0.0; // reset resources usage
				} // no production outputs or emissions
				
				loop u over: transports_consumption_T.keys{
					tick_penurie[r][u] <- 0.0; //indiquer des moyens de transport ceux qui sont insuffisants
				}
				
				loop a over:types_deplacement {
					tick_pop_consumption_T[r][a] <- 0;
				}
			}
			
			
		}
		
		bool produce(int id, string region, map<string, float> demand) {
			bool ok <- true;
			
			loop c over: demand.keys{
				loop u over: production_inputs_T{//sorte d'énergie: "any_energy"
					float poi;
					try{
						poi <- production_output_inputs_T[c][u];
					}
					catch{
						poi <- 0.0;
					}
					float quantity_needed <-  poi + demand[c]; // quantify the resources consumed/emitted by this demand
					// write "external_producers.keys=" + external_producers.keys;
					if(external_producers.keys contains u){ // if there is a known external producer for this product/good
						// write "external_producers[u].producer=" + external_producers[u].producer;
						bool av <- external_producers[u].producer.produce(id, region, [u::quantity_needed]); // ask the external producer to product the required quantity
						if not av{
							ok <- false; //pas réussi à obtenir une quantité suffisante à consommer
						}
					}
					else{
						write "pas trouvé de producteur externe";
						ok <- false; //vérifier si on bien trouve le producteur externe
					}
					if(ok){
						// write "quantity consumed added";
						tick_resources_used[region][u] <- tick_resources_used[region][u] + quantity_needed;
					}
				}
//				tick_production[c] <- tick_production[c] + demand[c]; //?
			}
			
			return ok;
		}
			
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
		
	}
	
	species transport_consumer parent:consumption_agent{
	
		map<string, map<string, float>> consumed <- [];
		
		map<string, map<string, float>> get_tick_consumption_region{
			return copy(consumed);
		}
		
		map<string, map<int, map<string, float>>> get_tick_consumption_mv{
			map<string, map<int, map<string, float>>> tmp <- []; 
			return tmp;
		}
		
		init{
			loop r over: nom_region{
				consumed[r] <- [];
				loop c over: consumed.keys{ // reset choices counters
	    			consumed[r][c] <- 0;
	    		}
			}
		}
		
		action reset_tick_counters{ 
			loop r over: nom_region{
				loop c over: consumed.keys{ // reset choices counters
	    			consumed[r][c] <- 0;
	    		}
			}
		}
		
		string transport_choice_loisir(float distance_loisir) {
			switch distance_loisir{
				match_between [taxi_min_loisir, #infinity]{
					return taxi;
				}
				match_between [minibus_min_loisir, taxi_min_loisir]{
					return minibus;
				}
				default{
					return pied;
				}
			}
		}
		string transport_choice_scolarite {
			/*if flip(0.5) {
				return velo;
			}*/
			return minibus;
		}
		
		string transport_choice_ {
			return camion;
		}
		
        
        action consume_all(string region, map<string, map<string, int>> all) {
        	do consume_activites(region, all[activite]);
        	do consume_loisirs(region, all[loisir]);
        }
        
        action consume_activites(string region, map<string, int> activites) {
        	
        	loop k over: activites.keys {
        		switch(k) {
        			match(scolarite) {
        				int nb_etu <- activites[k];
						string transport_scolarite <- transport_choice_scolarite();
                      	
                      	float consumption_unique_scolarite <- distance_scolarite * 2 * travail_par_mois * transports_consumption_T[transport_scolarite];                     	
                      	float all_consumption_scolarite <- consumption_unique_scolarite * nb_etu;
                      	
                      	consumed[region][scolarite] <- consumed[region][scolarite] + all_consumption_scolarite;
						consumed[region][any_energy] <- consumed[region][any_energy] + all_consumption_scolarite;
          	          
        				
        			}
        			
        			match(travail) {
        				int nb_workers <- activites[k];
                    	float consumption_unique_worker <- distance_travail * 2 * travail_par_mois * transports_consumption_T[transport_par_activite[travail]];
						float all_consumption_workers <- consumption_unique_worker * nb_workers;
                    	
                    	consumed[region][travail] <- consumed[region][travail] + all_consumption_workers;
                		consumed[region][any_energy] <- consumed[region][any_energy] + all_consumption_workers;
        				
        			}
        		}
        	}
        }
        
        action consume_loisirs(string region, map<string, int> loisirs) {
        	loop k over:loisirs.keys {
        		int nb_pers <- loisirs[k];
        		
        		float distance_loisir <- distances_loisirs_T[k];
                string type_transport <- transport_choice_loisir(distance_loisir);
                
                float consumption_unique_loisir <- distance_loisir * 2 * loisir_par_mois * transports_consumption_T[type_transport];
                float all_consumption_loisir <- consumption_unique_loisir * nb_pers;
                
                consumed[region][loisir] <- consumed[region][loisir] + all_consumption_loisir;
                consumed[region][any_energy] <- consumed[region][any_energy] + all_consumption_loisir;
        		
        	}
        }
        
        action consume(miniville mv){
        	do consume_all(mv.region, mv.repartition_additional_attributes);
		}
	}
	
}

experiment test_graph type:test autorun:false{
	test "TestGraph" {
		write("Strarting");
		write distance_graph;
		write("Identifiers : ");
		
		write(correspondance_ville_point);
		
		ask transport {
			string depart <- centre_val_de_loire;
			string arr <- pays_de_la_loire;
	
			do ask_transport_externe(depart, arr, "", 0.0);
		}
		
		write("Finished");
	}
}

experiment run_transport type: gui {

	output {
		display Transport_information {
			chart "Population direct consumption" type: series  size: {0.5,0.5} position: {0, 0} {	
			    loop r over: nom_region {
			    	loop c over: production_inputs_T{//only consume, do not have products
			    		data c value: (cycle > 0) ? tick_pop_consumption_T[r][c] : 0; // note : products consumed by other blocs NOT included here (only population direct consumption)
			    	
			   		}
			    }
			    
			}
			
			chart "Consumption by sources" type: series  size: {0.5,0.5} position: {0.5, 0} {
				loop r over: nom_region {
					loop c over: types_deplacements_activite{//only consume, do not have products
			    		data c value: (cycle > 0) ? tick_pop_consumption_T[r][c] : 0; // note : products consumed by other blocs NOT included here (only population direct consumption)
			    	
			    	}
		    	}
	    	}
			 
			chart "Consumption by sources cumulated" type: series  size: {0.5 ,0.5} position: {0, 0.5} {				
				loop r over: nom_region {
					loop c over: types_deplacements_activite{
			    		data c value: (cycle > 0) ? tick_pop_consumption_T_cumulated[r][c] : 0; // note : products consumed by other blocs NOT included here (only population direct consumption)
			    	}
				}
			    
			} 
						
			chart "Consumption externe" type:series size: {0.5, 0.5} position: {0.5, 0.5} {
				loop reg over: nom_region {
		    		data reg value: (cycle > 0) ? tick_pop_consumption_T[reg][externe] : 0; // note : products consumed by other blocs NOT included here (only population direct consumption)	
				}
			    
			}
			
			
	    }
	}
}
