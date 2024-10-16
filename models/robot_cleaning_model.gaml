
/**
 * Name: robot_cleaning_model
 * Author: 
 * 	- Felipe Guzmán Rodríguez
 * 	- Pablo Díaz-Masa Valencia
 *
 * Description:
 * This model simulates an environment where cleaning robots, sensors, supply closets, 
 * and charging stations interact to maintain cleanliness.
 */

model robot_cleaning_model

global torus: false {
	
	/**
     * Environment parameters
     * - size: Grid size (100x100).
     * - cycles: Simulation step counter.
     * - total_cycles: Total step counter (does not reset).
     * - cycles_to_pause: Cycles before pausing the simulation.
     * - simulation_over: Ends the simulation.
     */
    float size <- 100.0;
    geometry grid_shape <- rectangle(size, size);
    int cycles <- 0;
    int total_cycles <- 0;
    int cycles_to_pause <- 1000;
    bool simulation_over <- false;

	/**
     * Simulation setup
     * - num_robots: Number of robots.
     * - num_sensors: Number of sensors.
     * - num_supply_closets: Number of supply closets.
     * - num_charging_stations: Number of charging stations.
     * - dirt_quantity: Number of dirt patches.
     */
    int num_robots <- 5;
    int num_sensors <- 1;
    int num_supply_closets <- 1;
    int num_charging_stations <- 1;
    int dirt_quantity <- 1;
    
    // Dirt generation control
    int dirt_generation_interval <- 80;
    int last_dirt_generation <- 0;
    
    /**
     * Robot-specific settings
     * - initial_battery: Starting battery level.
     * - battery_threshold: Minimum battery level to recharge.
     * - initial_bags: Starting number of trash bags.
     * - initial_detergent: Initial detergent amount.
     */
    int initial_battery <- 100;
    int battery_threshold <- 20;
    int initial_bags <- 1;
    int initial_detergent <- 100;
    
    /**
     * Sensor detection radius
     * - radius: Detection range of sensors.
     */
    float radius <- 15.0;

    /**
     * Role names for DF registration
     * - Robot_role: Role for robots.
     * - Sensor_role: Role for sensors.
     * - ChargingStation_role: Role for charging stations.
     * - SupplyCloset_role: Role for supply closets.
     * - Dirt_role: Role for dirt patches.
     */
    string Robot_role <- "Robot";
    string Sensor_role <- "Sensor";
    string ChargingStation_role <- "ChargingStation";
    string SupplyCloset_role <- "SupplyCloset";
    string Dirt_role <- "Dirt";

	/**
     * Communication actions
     * - sweep_action: Robot sweeps.
     * - mop_action: Robot mops.
     * - collect_action: Robot collects dirt.
     * - recharge_action: Request battery recharge.
     * - supply_resource_action: Request resources.
     */
    string sweep_action <- "Sweep";
    string mop_action <- "Mop";
    string collect_action <- "Collect";
    string recharge_action <- "Recharge";
    string supply_resource_action <- "Supply_Resource";
	
	/**
     * Communication predicates
     * - dirt_detected: Dirt detected.
     * - resource_needed: Resource needed.
     * - resource_provided: Resource provided.
     * - battery_low: Low battery.
     */
    string dirt_detected <- "Dirt_Detected";
    string resource_needed <- "Resource_Needed";
    string resource_provided <- "Resource_Provided";
    string battery_low <- "Battery_Low";

	/**
     * Message concepts
     * - dirt_type: Type of dirt.
     * - location_concept: Location of dirt.
     * - resource_type: Type of resource.
     */
    string dirt_type <- "Dirt_Type";
    string location_concept <- "Location";
    string resource_type <- "Resource_Type";
  
	/**
     * Initial setup: Creates agents in the environment
     * - df, charging stations, supply closets, sensors, robots, and dirt patches.
     */
	 init {
	 	create species: df number: 1;
	    create species: charging_station number: num_charging_stations;
	    create species: supply_closet number: num_supply_closets;

	    loop i from: 0 to: 2 {
	        loop j from: 0 to: 2 {
	            create species: environmental_sensor number: 1 {
	                location <- {(size / 3) * (i + 0.5), (size / 3) * (j + 0.5)};
	            }
	        }
	    }
	    
	    create species: cleaning_robot number: num_robots;
	    create species: dirt number: dirt_quantity;
	}
    
    /**
     * Reflex: counting
     * Increments cycle counters every step.
     */
    reflex counting {
        cycles <- cycles + 1;
        total_cycles <- total_cycles + 1;
    }
    
    /**
     * Reflex: generate_dirt
     * Creates dirt every specified number of cycles.
     */
    reflex generate_dirt {
        if (total_cycles - last_dirt_generation >= dirt_generation_interval) {
            last_dirt_generation <- total_cycles;
            create species: dirt number: 1;
        }
    }

	/**
     * Reflex: pausing
     * Pauses the simulation after a set number of cycles.
     */
    reflex pausing when: cycles = cycles_to_pause {
        cycles <- 0;
        write "Simulación pausada tras " + cycles_to_pause;
        do pause;
    }

	/**
     * Reflex: halting
     * Stops the simulation when the flag is set.
     */
    reflex halting when: simulation_over {
        write "Finalizando simulación";
        do die;
    }
}

grid my_grid width: size height: size neighbors: 8 {}

/**
 * Species: df (Directory Facilitator)
 * Manages agent registration and role-based search.
 */
species df {

    /**
     * Attributes:
     * - yellow_pages: List of role-agent pairs.
     */
    list<pair> yellow_pages <- [];
    
    /**
     * Method: register
     * Registers an agent with a specific role.
     * 
     * @param the_role: Role for the agent.
     * @param the_agent: Agent to register.
     * @return registered: Boolean indicating success.
     */
    bool register(string the_role, agent the_agent) {
        bool registered;
        add the_role::the_agent to: yellow_pages;
        return registered;
    }
    
    /**
     * Method: search
     * Finds agents registered with a specific role.
     * 
     * @param the_role: Role to search for.
     * @return found_ones: List of agents with the role.
     */
    list<agent> search(string the_role) {
        list<agent> found_ones <- [];
        loop candidate over: yellow_pages {
            if (candidate.key = the_role) {
                add item: candidate.value to: found_ones;
            }
        }
        return found_ones;
    }
}

/**
 * Species: charging_station
 * Manages robot battery recharging requests.
 */
species charging_station skills: [fipa] control: simple_bdi {
	
	/**
     * Attributes:
     * - occupied: Indicates if a robot is being charged.
     * - current_cycle: Cycles left for charging.
     * - charging_time: Total cycles needed for a full charge.
     * - charging_robot_request: Current robot's request being processed.
     */
    bool occupied <- false; 
    int current_cycle <- 0;
    int charging_time <- 10;
    message charging_robot_request <- nil;
    
    /**
     * Initialization: Sets the location and registers in the DF.
     */
    init {
        location <- {size / 2 - 5, 5};
        
        ask df {
            bool registered <- register(ChargingStation_role, myself);
        }
    }
    
    /**
     * Reflex: receive_request
     * Starts charging if the station is free.
     */
    reflex receive_request when: !empty(requests) and !occupied {
        message requestFromRobot <- requests[0];
        write 'Estación de carga recibe una solicitud del robot con contenido ' + requestFromRobot.contents;
       
        do agree message: requestFromRobot contents: requestFromRobot.contents;

        occupied <- true;
        current_cycle <- charging_time;
        charging_robot_request <- requestFromRobot;

        write "Estación de carga comienza la recarga, que durará " + charging_time + " ciclos.";
    }

	/**
     * Reflex: charging_progress
     * Handles the charging process cycle by cycle and informs when done.
     */
    reflex charging_progress when: occupied {
        current_cycle <- current_cycle - 1; 

        if (current_cycle = 0) {
            list contents;
            string predicado <- resource_provided;
            list concept_list <- [];
            pair resource_type_pair <- resource_type::"battery";
            pair quantity_pair <- "battery_level"::100;
            add resource_type_pair to: concept_list;
            add quantity_pair to: concept_list;
            pair content_pair_resp <- predicado::concept_list;
            add content_pair_resp to: contents;

            do inform message: charging_robot_request contents: contents;

            write "Estación de carga proporcionó recarga de batería completa al robot.";
            
            occupied <- false;
            charging_robot_request <- nil;
        } else {
            write "Recarga en progreso... Quedan " + current_cycle + " ciclos.";
        }
    }

	/**
     * Visual aspect: Green square for the charging station.
     */
    aspect station_aspect {
        draw geometry: square(5) color: rgb("green");
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("EC") color: #white font:font("Roboto", 20 , #bold) at: pt2;
    }
}

/**
 * Species: supply_closet
 * Provides resources (detergent, trash bags) to robots upon request.
 */
species supply_closet skills: [fipa] control: simple_bdi {

	/**
     * Initialization: Sets location and registers in the DF.
     */
    init {
        location <- {size / 2 + 5, 5};
        ask df {
            bool registered <- register(SupplyCloset_role, myself);
        }
    }
    
    /**
     * Reflex: receive_request
     * Processes resource requests from robots.
     */
    reflex receive_request when: !empty(requests) {
        message requestFromRobot <- requests[0];
        write 'Armario de repuestos recibe una solicitud del robot con contenido ' + requestFromRobot.contents;
        
        do agree message: requestFromRobot contents: requestFromRobot.contents;

        list contentlist <- list(requestFromRobot.contents);
        map content_map <- contentlist at 0;
        pair content_pair <- content_map.pairs at 0;
        string accion <- string(content_pair.key);
        list conceptos <- list(content_pair.value);
        map conceptos_map <- conceptos at 0;
        string requested_resource <- string(conceptos_map[resource_type]);
        
        list contents;
        string predicado <- resource_provided;
        list concept_list <- [];
        pair resource_type_pair <- resource_type::requested_resource;
        pair quantity_pair <- "quantity"::5;
        add resource_type_pair to: concept_list;
        add quantity_pair to: concept_list;
        pair content_pair_resp <- predicado::concept_list;
        add content_pair_resp to: contents;

        do inform message: requestFromRobot contents: contents;

        write "Armario de repuestos proporcionó 5 unidades de " + requested_resource + " al robot.";
    }

	/**
     * Visual aspect: Orange rectangle representing the supply closet.
     */
    aspect closet_aspect {
        draw geometry: rectangle(10, 4) color: rgb("orange");
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("AR") color: #white font:font("Roboto", 20 , #bold) at: pt2;
    }
}

/**
 * Species: environmental_sensor
 * Detects dirt within a radius and sends cleaning requests to robots.
 */
species environmental_sensor skills: [fipa] control: simple_bdi {
    
    /**
     * Initialization: Registers the sensor in the DF.
     */
    init {
        ask df {
            bool registered <- register(Sensor_role, myself);
        }
    }

	/**
     * Reflex: detect_dirt
     * Detects dirt within the sensor's radius and assigns it to a robot.
     */
	reflex detect_dirt {
	    loop dirt_instance over: species(dirt) {
	        point dirt_location <- dirt_instance.location;
	
	        float distance_to_dirt <- sqrt((location.x - dirt_location.x) ^ 2 + (location.y - dirt_location.y) ^ 2);
	
	        if (distance_to_dirt <= radius and !dirt_instance.already_detected) {
	            write "Suciedad detectada en " + dirt_location + " - Distancia: " + distance_to_dirt + " - Tipo: " + dirt_instance.type;
	            dirt_instance.already_detected <- true;
	            dirt_instance.detected_by_sensor <- self;
	
	            list contents;
	            string predicado <- dirt_detected;
	            list concept_list <- [];
	
	            pair dirt_type_pair <- dirt_type::dirt_instance.type;
	            pair location_pair <- location_concept::dirt_location;
	            add dirt_type_pair to: concept_list;
	            add location_pair to: concept_list;
	
	            pair content_pair_resp <- predicado::concept_list;
	            add content_pair_resp to: contents;
	
	            if (!dirt_instance.assigned_to_robot) {
	                loop robot over: species(cleaning_robot) {
	                    if (!robot.cleaning_in_progress) {
	                        write "Sensor enviando solicitud de limpieza al robot con ubicación: " + dirt_location;
	                        do start_conversation to: [robot] protocol: 'fipa-request' performative: 'request' contents: contents;
	                        dirt_instance.assigned_to_robot <- true; 
	                        break;
	                    }
	                }
	            }
	        }
	    }
	}
	
	/**
     * Visual aspect: Red circle for the sensor and its detection radius.
     */
    aspect sensor_aspect {
        draw geometry: circle(1) color: rgb("red") at: location; // Representar el sensor pequeño
        draw circle(radius) color: rgb("#ffcfcf", 70) border: rgb("#ff2929", 130) at: location; // Dibujar el área de detección circular
    }
}

/**
 * Species: cleaning_robot
 * Manages movement, requests resources, and cleans dirt.
 */
species cleaning_robot skills: [moving, fipa] control: simple_bdi {
   
   /**
     * Attributes:
     * - my_supply_closets: Available supply closets.
     * - my_charging_stations: Available charging stations.
     * - pending_cleaning_tasks: List of pending cleaning tasks.
     * - assigned_dirt_locations: Dirt locations assigned to this robot.
     * - cleaning_in_progress: Indicates if the robot is currently cleaning.
     */
    list<agent> my_supply_closets;
    list<agent> my_charging_stations;
    list<point> pending_cleaning_tasks <- [];
    list<point> assigned_dirt_locations <- [];
    bool cleaning_in_progress <- false;

	/**
     * Belief attributes
     * - Stores beliefs about location, battery, resources, and assigned agents.
     */
    string at_supply_closet <- "at_supply_closet";
    string at_charging_station <- "at_charging_station";
    string resource_needed_belief <- "resource_needed";
    string battery_low_belief <- "battery_low";
    string my_supply_closet <- "my_supply_closet";
    string my_charging_station <- "my_charging_station";
    string battery_level <- "battery_level";
    string bags_quantity <- "bags_quantity";
    string detergent_level <- "detergent_level";

	/**
     * Predicates: Actions and desires for resource requests and movement.
     */
    predicate request_resource <- new_predicate("request_resource");
    predicate request_charge <- new_predicate("request_charge");
    predicate move_to_supply_closet <- new_predicate("move_to_supply_closet");
    predicate move_to_charging_station <- new_predicate("move_to_charging_station");
    predicate move_to_random_location <- new_predicate("move_to_random_location");
    predicate clean_dirt <- new_predicate("clean_dirt");
    
	/**
     * Initialization: Sets location, speed, and registers robot in the DF.
     * Also initializes the robot's beliefs (battery, resources).
     */
    init {
        speed <- 10.0;
        location <- rnd(point(size, size));

        ask df {
            bool registered <- register(Robot_role, myself);
            myself.my_supply_closets <- search(SupplyCloset_role);
            myself.my_charging_stations <- search(ChargingStation_role);
        }

        do add_belief(new_predicate(battery_level, ["level"::initial_battery]));
        do add_belief(new_predicate(bags_quantity, ["quantity"::initial_bags]));
        do add_belief(new_predicate(detergent_level, ["level"::initial_detergent]));

        if (!empty(my_supply_closets)) {
            do add_belief(new_predicate(my_supply_closet, ["agent"::(my_supply_closets at 0)]));
        }
        if (!empty(my_charging_stations)) {
            do add_belief(new_predicate(my_charging_station, ["agent"::(my_charging_stations at 0)]));
        }
    }

	/**
     * Rule: Moving to supply closet when resource is needed.
     */
    rule beliefs: [new_predicate(resource_needed_belief)] when: !has_belief(new_predicate(at_supply_closet)) new_desire: move_to_supply_closet;

	/**
     * Rule: Moving to supply closet when resource is needed.
     */
    rule beliefs: [new_predicate(battery_low_belief)] when: !has_belief(new_predicate(at_charging_station)) new_desire: move_to_charging_station;

	/**
     * Plan: request_resource
     * Handles requests for resources (detergent or bags) if at the supply closet.
     */
    plan request_resource intention: request_resource {
        if (has_belief(new_predicate(at_supply_closet))) {
            predicate pred_resource_needed <- get_predicate(get_belief(new_predicate(resource_needed_belief)));
            string resource_type_needed <- string(pred_resource_needed.values["type"]);

            do remove_belief(pred_resource_needed);

            predicate pred_supply_closet <- get_predicate(get_belief(new_predicate(my_supply_closet)));
            agent the_supply_closet <- agent(pred_supply_closet.values["agent"]);

            list contents;
            list concept_list <- [];
            pair resource_type_pair <- resource_type::resource_type_needed;
            add resource_type_pair to: concept_list;
            pair content_pair <- supply_resource_action::concept_list;
            add content_pair to: contents;

            do start_conversation to: [the_supply_closet] protocol: 'fipa-request' performative: 'request' contents: contents;

            write "Robot solicitando recurso " + resource_type_needed + " al armario de repuestos.";

            do remove_intention(request_resource);
            do remove_desire(request_resource);
        }
    }

	/**
     * Plan: request_charge
     * Requests battery recharge if at the charging station.
     */
    plan request_charge intention: request_charge {
        if (has_belief(new_predicate(at_charging_station))) {
            predicate pred_charging_station <- get_predicate(get_belief(new_predicate(my_charging_station)));
            agent the_charging_station <- agent(pred_charging_station.values["agent"]);

            list contents;
            pair content_pair <- recharge_action::[];
            add content_pair to: contents;

            do start_conversation to: [the_charging_station] protocol: 'fipa-request' performative: 'request' contents: contents;

            write "Robot solicitando recarga de batería a la estación de carga.";

            do remove_intention(request_charge);
            do remove_desire(request_charge);
        }
    }
	
	/**
     * Plan: move_to_supply_closet
     * Moves robot to the supply closet to request resources.
     */
    plan move_to_supply_closet intention: move_to_supply_closet {
        predicate pred_my_supply_closet <- get_predicate(get_belief(new_predicate(my_supply_closet)));
        agent the_supply_closet <- agent(pred_my_supply_closet.values["agent"]);
        point target_location <- the_supply_closet.location;

        float distance <- sqrt((location.x - target_location.x) ^ 2 + (location.y - target_location.y) ^ 2);

        if (distance > 0.5) {
            float step_size <- min(2.0, distance);
            float direction_x <- (target_location.x - location.x) / distance;
            float direction_y <- (target_location.y - location.y) / distance;

            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
            do goto target: next_step;

        } else {
            do add_belief(new_predicate(at_supply_closet));
            write "Robot llegó al armario de repuestos.";

            do add_desire(request_resource);
        }

        if (has_belief(new_predicate(at_supply_closet))) {
            do remove_intention(move_to_supply_closet);
            do remove_desire(move_to_supply_closet);
        }
    }

	/**
	 * Plan: move_to_charging_station
	 * Moves the robot step-by-step to the charging station. Once it arrives, it updates beliefs and requests a recharge.
	 */
    plan move_to_charging_station intention: move_to_charging_station {
        predicate pred_my_charging_station <- get_predicate(get_belief(new_predicate(my_charging_station)));
        agent the_charging_station <- agent(pred_my_charging_station.values["agent"]);
        point target_location <- the_charging_station.location;

        float distance <- sqrt((location.x - target_location.x) ^ 2 + (location.y - target_location.y) ^ 2);

        if (distance > 0.5) {
            float step_size <- min(2.0, distance);
            float direction_x <- (target_location.x - location.x) / distance;
            float direction_y <- (target_location.y - location.y) / distance;

            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
            do goto target: next_step;

        } else {
            do add_belief(new_predicate(at_charging_station));
            write "Robot llegó a la estación de carga.";

            do add_desire(request_charge);
        }

        if (has_belief(new_predicate(at_charging_station))) {
            do remove_intention(move_to_charging_station);
            do remove_desire(move_to_charging_station);
        }
    }

	/**
	 * Plan: move_to_random_location
	 * Moves the robot to a random location on the grid.
	 */
	plan move_to_random_location intention: move_to_random_location {
	    point random_location <- rnd(point(size, size));
	    do goto target: random_location;
	    
	    write "Robot se movió a una ubicación aleatoria: " + random_location;
	
	    do remove_intention(move_to_random_location);
	    do remove_desire(move_to_random_location);
	}

	/**
     * Plan: move_to_clean_dirt
     * Moves robot to dirt location and cleans it.
     */	
	plan move_to_clean_dirt intention: clean_dirt {
	    if (!empty(pending_cleaning_tasks)) {
	        point dirt_location <- pending_cleaning_tasks[0];
	
	        float distance <- sqrt((location.x - dirt_location.x) ^ 2 + (location.y - dirt_location.y) ^ 2);
	        
	        if (distance > 0.5) {
	            float step_size <- min(2.0, distance);
	            float direction_x <- (dirt_location.x - location.x) / distance;
	            float direction_y <- (dirt_location.y - location.y) / distance;
	
	            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
	            do goto target: next_step;
	
	        } else {
	            write "Robot llegó a la suciedad en " + dirt_location;
	            loop dirt_instance over: species(dirt) {
	                if (dirt_instance.location = dirt_location) {
	                    write "Robot limpia la suciedad en " + dirt_location;
	                    ask dirt_instance {
	                        do die;
	                    }
	                }
	            }
	
	            remove dirt_location from: pending_cleaning_tasks;
	
	            do remove_intention(clean_dirt);
	            cleaning_in_progress <- false;
	        }
	    } else {
	        //write "No hay más tareas de limpieza pendientes.";
	        cleaning_in_progress <- false;
	        do remove_intention(clean_dirt);
	    }
	}
	
	/**
     * Reflex: receive_inform
     * Updates robot's beliefs and resources based on incoming inform messages.
     */
    reflex receive_inform when: !empty(informs) {
        message informMessage <- informs[0];
        write 'Robot recibe un mensaje inform con contenido ' + informMessage.contents;

        pair content_pair <- informMessage.contents[0];

        if (content_pair.key = resource_provided) {
            list conceptos_list <- content_pair.value;
            map conceptos_map <- map(conceptos_list);
            string provided_resource <- string(conceptos_map[resource_type]);
            int provided_quantity <- int(conceptos_map["quantity"]);

            if (provided_resource = "detergent") {
                predicate pred_detergent <- get_predicate(get_belief(new_predicate(detergent_level)));
                int current_detergent <- int(pred_detergent.values["level"]);
                current_detergent <- current_detergent + provided_quantity;
                do remove_belief(pred_detergent);
                do add_belief(new_predicate(detergent_level, ["level"::current_detergent]));
                write "Robot actualizó su nivel de detergent a " + current_detergent;
                
            } else if (provided_resource = "trash_bags") {
                predicate pred_bags <- get_predicate(get_belief(new_predicate(bags_quantity)));
                int current_bags <- int(pred_bags.values["quantity"]);
                current_bags <- current_bags + provided_quantity;
                do remove_belief(pred_bags);
                do add_belief(new_predicate(bags_quantity, ["quantity"::current_bags]));
                write "Robot actualizó su cantidad de bolsas a " + current_bags;
            }
            
        	do add_desire(move_to_random_location);
        } else if (content_pair.key = recharge_action) {
            predicate pred_battery <- get_predicate(get_belief(new_predicate(battery_level)));
            do remove_belief(pred_battery);
            do add_belief(new_predicate(battery_level, ["level"::initial_battery]));
            write "Robot ha completado la recarga de batería. Nivel de batería: " + initial_battery;

            do remove_belief(new_predicate(battery_low_belief));
        	do add_desire(move_to_random_location);
        }
    }
	
	/**
	 * Reflex: receive_request
	 * Processes incoming cleaning requests and adds them to the task list if the dirt is not already assigned.
 	*/
	reflex receive_request when: !empty(requests) {
	    message requestMessage <- requests[0];
	    pair content_pair <- requestMessage.contents[0];
	
	    if (content_pair.key = dirt_detected) {
	        list conceptos_list <- content_pair.value;
	        map conceptos_map <- map(conceptos_list);
	        point dirt_location <- point(conceptos_map[location_concept]);
	
	        loop dirt_instance over: species(dirt) {
	            if (dirt_instance.location = dirt_location) {
	                if (dirt_instance.assigned_to_robot) {
	                    add dirt_location to: pending_cleaning_tasks;
	                    dirt_instance.assigned_to_robot <- true;
	                    write "Robot recibe nueva solicitud de limpieza para la ubicación: " + dirt_location;
	
	                    if (!cleaning_in_progress) {
	                        cleaning_in_progress <- true;
	                        do add_desire(clean_dirt);
	                    }
	                }
	            }
	        }
	    }
	}

	/**
     * Visual aspect: Small purple circle representing the robot.
     */
    aspect robot_aspect {
        draw circle(2.5) color: rgb("purple") at: location;
    }
}

/**
 * Species: dirt
 * Represents different types of dirt (dust, liquid, garbage) that sensors detect.
 */
species dirt {

    /**
     * Attributes:
     * - type: Type of dirt (dust, liquid, garbage).
     * - already_detected: Indicates if the dirt has been detected by a sensor.
     * - dirt_color: Color representing the type of dirt.
     * - detected_by_sensor: Sensor that detected the dirt.
     * - assigned_to_robot: Indicates if the dirt has been assigned for cleaning.
     */
    string type;
    bool already_detected <- false;
    rgb dirt_color;
    agent detected_by_sensor <- nil;
	bool assigned_to_robot <- false;
	
    /**
     * Initialization: Registers dirt in the DF and positions it near a sensor if available.
     */
    init {
        list<agent> sensors;

        ask df {
            bool registered <- register(Dirt_role, myself);
        }

        ask df {
            sensors <- search(Sensor_role);
        }

        if (!empty(sensors)) {
            agent sensor_agent <- one_of(sensors);
            point sensor_location <- sensor_agent.location;
            point new_position <- nil;

            loop while: new_position = nil {
                float angle <- rnd(0.0, 2 * #pi);
                float distance <- rnd(0.0, radius);
                
                float x_offset <- cos(angle) * distance;
                float y_offset <- sin(angle) * distance;

                float new_x <- sensor_location.x + x_offset;
                float new_y <- sensor_location.y + y_offset;

                float distancia_a_sensor <- sqrt((new_x - sensor_location.x) ^ 2 + (new_y - sensor_location.y) ^ 2);

                if (distancia_a_sensor <= radius) {
                    new_position <- {new_x, new_y};
                }
            }

            location <- new_position;
        }

        type <- one_of(["dust", "liquid", "garbage"]);
        if (type = "dust") {
            dirt_color <- rgb("#a6a6a6");
        } else if (type = "liquid") {
            dirt_color <- rgb("#69a1ff");
        } else if (type = "garbage") {
            dirt_color <- rgb("#aa8222");
        }
    }

    /**
     * Visual aspect: Small square colored based on dirt type.
     */
    aspect name: dirt_aspect {
        draw geometry: square(5) color: dirt_color at: location;
    }
}

experiment cleaning_simulation type: gui {
    output {
        display cleaning_display type: java2D {
            grid my_grid border: rgb("#C4C4C4");
            species charging_station aspect: station_aspect;
            species supply_closet aspect: closet_aspect;
            species environmental_sensor aspect: sensor_aspect;
            species cleaning_robot aspect: robot_aspect;
            species dirt aspect: dirt_aspect;
        }
    }
}
