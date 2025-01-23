/**
* Name: Demography bloc (MOSIMA)
* Authors: Maël Franceschetti, Cédric Herpson, Jean-Daniel Kant
* Mail: firstname.lastname@lip6.fr
*/

model Demography

import "../API/API.gaml"
import "StringUtils.gaml"
import "InfoRegion.gaml"

/**
 * We define here the global variables of the bloc. Some are needed for the displays (charts, series...).
 */
global{
	/* Setup */ 
	int nb_ticks_per_year <- 12; // here, one tick is one month
	string female_gender <- "F";
	string male_gender <- "M";
	list<string> genders <- ["F", "M"];
	
	/* Input data (data for 2018, source : INSEE) */ 
	map<string, map<int, float>>  init_age_distrib <- load_gender_data("../includes/data/init_age_distribution.csv"); // load initial ages distribution among the population for each gender
	map<string, map<int, float>> death_proba <- load_gender_data("../includes/data/death_probas.csv"); // load the probabilities to die in a year for each gender (per individual)
	map<string, map<int, float>> birth_proba <- load_gender_data("../includes/data/birth_probas.csv");
	map<string, int> region_pop <- load_nb_population("../includes/data/region_distribution.csv");
	map<string, float> init_gender_distrib <- [ // initial gender distribution in the population
		male_gender ::0.4839825904115131, 
		female_gender ::0.516017409588487
	];  // ne need to use a csv file here, just two values
	map <string, float> init_loisir_distrib <- [
		espace_naturel::0.5,
		exterieur::0.3,
		domicile::0.2
	];
	map <string, float> init_activity_distrib <- [
		scolarite::0.13,
		travail::0.87
	];
	list<int> ages <- init_age_distrib[male_gender].keys;
	
	/* Parameters */ 
	float coeff_birth <- 0.33; // a parameter that can be used to increase or decrease the birth probability
	float coeff_death <- 0.6; // a parameter that can be used to increase or decrease the death probability
	
	/* Counters & Stats */
	// int nb_inds -> {length(individual)};
	int nb_men_total;
	int nb_woman_total;
	int nb_pop_total;
	
	int nb_pop_U20;
	int nb_pop_U60;
	int nb_pop_U65;
	int nb_pop_U75;
	int nb_pop_O75;
	map <string, int> distribution_people <- [];
	int div;
	
	map<string, map<string, map<int, int>>> population_region <- [male_gender::[], female_gender::[]];
	// map<string, map<string, float>> proba_birth_par_age <- [];
	
	map<string, map<string, int>> age_distribution <- [male_gender::[], female_gender::[]];
	
	float births <- 0; // counter, accumulate the total number of births
	float deaths <- 0; // counter, accumulate the total number of deaths
	
	int counter <- 0;
	
	init{  
		// a security added to avoid launching an experiment without the other blocs
		if (length(coordinator) = 0){
			error "Coordinator agent not found. Ensure you launched the experiment from the Main model";
			// If you see this error when trying to run an experiment, this means the coordinator agent does not exist.
			// Ensure you launched the experiment from the Main model (and not from the bloc model containing the experiment).
		}
	}
	
	/* Load gender data (distribution, probabilities) per age category from a csv file */
	map<string, map<int, float>> load_gender_data(string filename){
		file input_file <- csv_file(filename, ","); // load the csv file and separate the columns
        matrix data_matrix <- matrix(input_file); // put the data in a matrix
        map<int, float> male_data <- create_map(data_matrix column_at 0, data_matrix column_at 1); // create a map from male data
        map<int, float> female_data <- create_map(data_matrix column_at 0, data_matrix column_at 2); // same for female data
        map<string, map<int, float>> data <- [male_gender::male_data, female_gender::female_data]; // zip it in a all-in-one map
        return data; // return it
	}
	
	/* récupérer le nombre d'habitant par région à paritir d'un fichier csv */
	map<string, int> load_nb_population(string filename){
		file input_file <- csv_file(filename, ",");
        matrix data_matrix <- matrix(input_file);
        map<string, int> data <- create_map(data_matrix column_at 0, data_matrix column_at 1);
        return data;
	}
	
}


/**
 * We define here the content of the demography (or "resident") bloc as a species.
 * We implement the methods of the API. Some are empty (do nothing) because this bloc do not have consumption nor production.
 * We also add methods specific to this bloc to handle the births and deaths in the population.
 */
species residents parent:bloc{
	string name <- "residents";
	bool enabled <- true; // true to activate the demography (births, deaths), else false.
	
	/* setup the resident agent : initialize the population */
	action setup{
		do init_region;
		write("mv_region : "+mv_region);
	}
	
	action tick_consumer(list<miniville> mv){
		do collect_last_tick_data;
		if(enabled){
			do update_births;
			do update_deaths;
			do increment_age;
		}
	}
	
	action tick_producer{

	}
	
	action tick_distribution{
		
	}
	
	list<string> get_input_resources_labels{ 
		return []; // no resources for demography component (function declared only to respect bloc API)
	}
	
	list<string> get_output_resources_labels{
		return []; // no resources for demography component (function declared only to respect bloc API)
	}
	
	production_agent get_producer{
		return nil; // no producer for demography component (function declared only to respect bloc API)
	}
	
	action collect_last_tick_data{ // update stats & measures
		// reset data
		nb_men_total <- 0;
		nb_woman_total <- 0;
		nb_pop_U20 <- 0;
		nb_pop_U60 <- 0;
		nb_pop_U65 <- 0;
		nb_pop_U75 <- 0;
		nb_pop_O75 <- 0;
		age_distribution <- [male_gender::[], female_gender::[]];
		
		loop region over: nom_region{
			population_region[region] <- [];
			population_region[region][male_gender] <- [];
			population_region[region][female_gender] <- [];
			loop age over: ages{
				population_region[region][male_gender][age] <- 0;
				population_region[region][female_gender][age] <- 0;
			}
		}
		
		// collection data
		ask ind_miniville{
			nb_men_total <- nb_men_total + sum(repartition_age[male_gender].values);
			nb_woman_total <- nb_woman_total + sum(repartition_age[female_gender].values);
			loop age over: repartition_age[male_gender].keys{
				switch age { 
			        match_between [0, 19] {nb_pop_U20 <- nb_pop_U20 + repartition_age[male_gender][age];}
			        match_between [20, 59] {nb_pop_U60 <- nb_pop_U60 + repartition_age[male_gender][age];}
			        match_between [60, 64] {nb_pop_U65 <- nb_pop_U65 + repartition_age[male_gender][age];}
			        match_between [65, 74] {nb_pop_U75 <- nb_pop_U75 + repartition_age[male_gender][age];}
			        default {nb_pop_O75 <- nb_pop_O75 + repartition_age[male_gender][age];} 
				}
				age_distribution[male_gender][string(age)] <- age_distribution[male_gender][string(age)] + repartition_age[male_gender][age];
				population_region[region][male_gender][age] <- population_region[region][male_gender][age] + repartition_age[male_gender][age];
			}
			loop age over: repartition_age[female_gender].keys{
				switch age { 
			        match_between [0, 19] {nb_pop_U20 <- nb_pop_U20 + repartition_age[female_gender][age];}
			        match_between [20, 59] {nb_pop_U60 <- nb_pop_U60 + repartition_age[female_gender][age];}
			        match_between [60, 64] {nb_pop_U65 <- nb_pop_U65 + repartition_age[female_gender][age];}
			        match_between [65, 74] {nb_pop_U75 <- nb_pop_U75 + repartition_age[female_gender][age];}
			        default {nb_pop_O75 <- nb_pop_O75 + repartition_age[female_gender][age];} 
				}
				age_distribution[female_gender][string(age)] <- age_distribution[female_gender][string(age)] + repartition_age[female_gender][age];
				population_region[region][female_gender][age] <- population_region[region][female_gender][age] + repartition_age[female_gender][age];
			}
		}
		nb_pop_total <- nb_men_total+nb_woman_total;
		write("[Demo] nb pop total : "+nb_pop_total);
		
		// calcul proportion
		div  <- nb_pop_total=0 ? 1: nb_pop_total;
		distribution_people["[0:19]"] <- (nb_pop_U20/div)*100;
		distribution_people["[20;59]"] <- (nb_pop_U60/div)*100;
		distribution_people["[60:64]"] <- (nb_pop_U65/div)*100;
		distribution_people["[65:74]"] <- (nb_pop_U75/div)*100;
		distribution_people["[75"] <- (nb_pop_O75/div)*100;

		// sort data
		map<string, float> tmp <- [];
		loop age over: age_distribution[male_gender].keys sort_by (int(each)){
			tmp[age] <- age_distribution[male_gender][age];
		}
		age_distribution[male_gender] <- tmp;
		
		tmp <- [];
		loop age over: age_distribution[female_gender].keys sort_by (int(each)){
			tmp[age] <- age_distribution[female_gender][age];
		}
		age_distribution[female_gender] <- tmp;
		
		// save csv
		// données nationales
		save [
				nb_pop_total, nb_men_total, nb_woman_total
		] to:"../resultat/demographie/data/data_demography.csv" rewrite: cycle>1 ? false : true header: true ;
		
		// données régionales
		loop region over: nom_region{
			int nb_men <- population_region[region][male_gender].values sum_of (each);
			int nb_woman <- population_region[region][female_gender].values sum_of (each);
			int nb_pop <- nb_men + nb_woman;
			save [
				nb_pop, nb_men, nb_woman
			] to:"../resultat/demographie/data/data_demography_"+region+".csv" rewrite: cycle>1 ? false : true header: true ;
		}
			
	}
	
	action population_activity(list<human> pop){
		 // no population activity for demography component (function declared only to respect bloc API)
	}
	
	action set_external_producer(string product, production_agent prod_agent){
		// no external producer for demography component (function declared only to respect bloc API)
	}
	
	/* initialise les régions */
	action init_region{
		write("nom region : "+nom_region);
		int nb_pop_init <- 0;
		loop r over: nom_region{
			mv_region[r] <- [];
			// write ("\nregion : "+r);
			int nb_pop_restant <- int(region_pop[r]/echelle);
			nb_pop_init <- nb_pop_init + nb_pop_restant;
			loop while: nb_pop_restant >= 0{
				// write("nb_pop_restant : "+nb_pop_restant);
				create ind_miniville number: 1{
					id <- counter;
					region <- r;
					nb_population <- min([nb_pop_restant, 10000]);
					loop gender over: genders{
						repartition_age[gender] <- [];
					}
					repartition_additional_attributes[loisir] <- [];
					repartition_additional_attributes[activite] <- [];
					loop times: nb_population{
						string gender <- rnd_choice(init_gender_distrib); // override gender, pick a gender with respect to the real distribution
						int age <- rnd_choice(init_age_distrib[gender]);  // pick an initial age with respect to the real distribution and gender
						string loisir_selected <- rnd_choice(init_loisir_distrib);
						string activity_selected <- (age < 18) ? scolarite : rnd_choice(init_activity_distrib);
						// write 'choix du centre de loisir: ' + loisir_selected;
						// write 'choix de activite: ' + activity_selected;
						
						repartition_age[gender][age] <- repartition_age[gender][age]+1;
						// write("rep_age : "+repartition_age);
						repartition_additional_attributes[loisir][loisir_selected] <- repartition_additional_attributes[loisir][loisir_selected]+1;
						// write("rep_add_att : "+repartition_additional_attributes);
						repartition_additional_attributes[activite][activity_selected] <- repartition_additional_attributes[activite][activity_selected]+1;
						// write("rep_add_att : "+repartition_additional_attributes);
					}
					do setup;
				}
				mv_region[r] <- mv_region[r] + counter;
				counter <- counter + 1;
				nb_pop_restant <- nb_pop_restant - 10000;
			}
		}
	}

   /* apply births */
	action update_births{ 
		int new_births <- 0;
		
		// une fois par an
		ask ind_miniville{
			if (ticks_before_birthday <= 0){
				loop age over: repartition_age[female_gender].keys{
					int nb_true <- 0;
					loop times: repartition_age[female_gender][age]{
						if (flip(p_birth[female_gender][age]*coeff_birth)){
							new_births <- new_births+1;
							nb_true <- nb_true + 1;					}
					}
					/*
					try{
						proba_birth_par_age[string(age)]["nb_true"] <- proba_birth_par_age[string(age)]["nb_true"] + nb_true;
						proba_birth_par_age[string(age)]["nb_woman"] <- proba_birth_par_age[string(age)]["nb_woman"] + repartition_age[female_gender][age];
					}
					catch{
						proba_birth_par_age[string(age)] <- [];
						proba_birth_par_age[string(age)]["nb_true"] <- proba_birth_par_age[string(age)]["nb_true"] + nb_true;
						proba_birth_par_age[string(age)]["nb_woman"] <- proba_birth_par_age[string(age)]["nb_woman"] + repartition_age[female_gender][age];
					}
					*/
				}
				nb_population <- nb_population + new_births;
				loop times: new_births{
					string g <- one_of ([female_gender, male_gender]);
					repartition_age[g][0] <- repartition_age[g][0]+1;
					
					string loisir_selected <- rnd_choice(init_loisir_distrib);
					repartition_additional_attributes[activite][scolarite] <- repartition_additional_attributes[activite][scolarite] + 1;
					repartition_additional_attributes[loisir][loisir_selected] <- repartition_additional_attributes[loisir][loisir_selected] + 1;
				}
			}
		}
		births <- births + new_births;
		
	}
	
	/* apply deaths*/
	action update_deaths{
		ask ind_miniville{
			if (ticks_before_birthday <= 0){
				loop gender over: genders{
					loop age over: repartition_age[gender].keys{
						// write("nb pop ("+age+") :"+repartition_age[gender][age]);
						// write("p_death["+gender+"]["+age+"] : "+p_death[gender][age]);
						// write("flip : "+flip(p_death[gender][age]));
						// int nb_true <- 0;
						loop times: repartition_age[gender][age]{
							if (flip(p_death[gender][age]=1 ? 1 : p_death[gender][age]*coeff_death)){
	
								string loisir_selected <- rnd_choice(init_loisir_distrib);
								string activity_selected <- age <= 17 ? scolarite : travail ;
								
								repartition_additional_attributes[loisir][loisir_selected] <- repartition_additional_attributes[loisir][loisir_selected] - 1;
								repartition_additional_attributes[activite][activity_selected] <- repartition_additional_attributes[activite][activity_selected] - 1;
								
								repartition_age[gender][age] <- repartition_age[gender][age]-1;
								nb_population <- nb_population - 1;
								deaths <- deaths +1;
								// nb_true <- nb_true +1;
								
							}
						}
						// float d <- repartition_age[gender][age] = 0 ? 0 : nb_true/repartition_age[gender][age];
						// write("p_death["+gender+"]["+age+"] calculé : "+d);
						// write("");
					}
				}
			}
		}
	}
	
	/* increments the age of the individual if the tick corresponds to its birthday, and updates birth and death probabilities */
	action increment_age{
		ask ind_miniville{
			if(ticks_before_birthday<=0){ // if the current tick is the individual birth date, increment the age
				map<string, map<int, int>> increment_age <- [];
				
				int new_workers <- 0;
				
				loop gender over: genders{
					increment_age[gender] <- [];
					loop age over: repartition_age[gender].keys{
						if(age = 17) {
							new_workers <- new_workers + repartition_age[gender][age]; 
						}
						increment_age[gender][age+1] <- repartition_age[gender][age];
					}
				}
				repartition_age <- copy(increment_age);
				ticks_before_birthday <- nb_ticks_per_year;
				
				repartition_additional_attributes[activite][scolarite] <- repartition_additional_attributes[activite][scolarite] - new_workers;
				repartition_additional_attributes[activite][travail] <- repartition_additional_attributes[activite][travail] + new_workers;
			}
			else{
				ticks_before_birthday <- ticks_before_birthday -1;
			}
		}
	}

}

/**
 * We define the agents used in the demography bloc. We here extends the 'human' species of the API to add some functionalities.
 * Be careful to define features that will only be called within the demography block, in order to respect the API.
 * 
 * The demography of our population will here be based on death and birth probabilities.
 * These probabilities will depend on somme attributes of the individuals (age, gender ...).
 * We propose some formulas for these probabilities, based on INSEE data. These are rough estimates.
 */
species ind_miniville parent:miniville{
	map<string, map<int, float>> p_death <- [];
	map<string, map<int, float>> p_birth <- [];
	int ticks_before_birthday;
	int delay_next_child <- 0;
	int child <- 0;
	
	init{
		ticks_before_birthday <- rnd(nb_ticks_per_year); // set a random birth date in the year (uniformly)
	}
	
	/* returns the age category matching the age of the individual from a list */
	int get_age_category(list<int> ages_categories, int age){
		int age_cat <- max(ages_categories where (each <= age)); // get the last age category with a lower bound inferior to the age
		return age_cat;
	}
	
	/* returns the probability for the individual to die this year */
	action set_p_death{ // compute monthly death probability of an individual
		loop gender over: genders{
			p_death[gender] <- [];
			loop age over: ages{
				int age_cat <- get_age_category(death_proba[gender].keys, age);
				p_death[gender][age] <-  death_proba[gender][age_cat];
			}
		
		}
	}
	
	/* returns the probability for the individual to give birth this year */
	action set_p_birth{
		loop gender over: genders{
			p_birth[gender] <- [];
			loop age over: ages{
				if (gender=male_gender){
					p_birth[gender][age] <-  0.0;
				}
				else{
					int age_cat <- get_age_category(birth_proba[gender].keys, age);
					p_birth[gender][age] <- birth_proba[gender][age_cat];
				}
					
			}
		}
			
	}
	
	action setup{
	    // set initial birth & death probabilities :
	    do set_p_birth; 
		do set_p_death;
	}
}

/**
 * We define here the experiment and the displays related to demography. 
 * We will then be able to run this experiment from the Main code of the simulation, with all the blocs connected.
 * 
 * Note : experiment car inherit another experiment, but we can't combine displays from multiple experiments at the same time. 
 * If needed, a new experiment combining all those displays should be added, for example in the Main code of the simulation.
 */
experiment run_demography type: gui {
	// parameter "Initial number of individuals" var: nb_init_individuals min: 0 category: "Initialisation";
	parameter "Coefficient for birth probability" var: coeff_birth min: 0.0 max: 1.0 category: "Demography";
	parameter "Coefficient for death probability" var: coeff_death min: 0.0 max: 1.0 category: "Demography";
	parameter "Number of ticks per year" var: nb_ticks_per_year min:1 category: "Simulation";

	output {
		display Population_information {
			chart "Gender evolution" type: series size: {0.5,0.33} position: {0, 0} {
				data "number_of_man" value: nb_men_total color: #blue;
				data "number_of_woman" value: nb_woman_total color: #red;
				data "total_individuals" value: nb_pop_total color: #black;
			}
			/* 
			chart "Age Pyramid" type: histogram background: #lightgray size: {0.5,0.5} position: {0, 0.5} {
				data "]0;15]" value: ind_miniville sum_of each.repartition_age[male_gender].keys <= 15 color:#blue;
				data "]15;30]" value: individual count (not dead(each) and (each.age > 15) and (each.age <= 30)) color:#blue;
				data "]30;45]" value: individual count (not dead(each) and (each.age > 30) and (each.age <= 45)) color:#blue;
				data "]45;60]" value: individual count (not dead(each) and (each.age > 45) and (each.age <= 60)) color:#blue;
				data "]60;75]" value: individual count (not dead(each) and (each.age > 60) and (each.age <= 75)) color:#blue;
				data "]75;90]" value: individual count (not dead(each) and (each.age > 75) and (each.age <= 90)) color:#blue;
				data "]90;105]" value: individual count (not dead(each) and (each.age > 90) and (each.age <= 105)) color:#blue;
			}
			*/
			chart "Births and deaths" type: series size: {0.5,0.33} position: {0.5, 0} {
				data "number_of_births" value: births color: #green;
				data "number_of_deaths" value: deaths color: #black;
			}
			chart "age_distribution male_gender" type: histogram size: {0.5,0.33} position: {0, 0.33} {
				datalist age_distribution[male_gender].keys value: cycle>0 ? age_distribution[male_gender].values : [];
			}
			chart "age_distribution female_gender" type: histogram size: {0.5,0.33} position: {0.5, 0.33} {
				datalist age_distribution[female_gender].keys value: cycle>0 ? age_distribution[female_gender].values : [];
			}
			chart "my_chart" type: histogram size: {0.5,0.33} position: {0, 0.66} {
				datalist distribution_people.keys value: cycle>0 ? distribution_people.values : [];
			}
			/*
			chart "proba birth" type: series size: {0.5,0.33} position: {0.5, 0.66} {
				loop age over: [15, 20, 25, 30, 35, 40, 45]{
					data "proba obs "+age value: cycle>0?proba_birth_par_age[string(age)]["nb_true"]/proba_birth_par_age[string(age)]["nb_woman"]:0 color: #green;
					data "proba reel "+age value: birth_proba[female_gender][age] color: #red;
				}
				
			}
			*/
		}
	}
}




