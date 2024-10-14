
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
     * - size: The grid size (100x100).
     * - grid_shape: 
     * - cycles: Counter for simulation steps.
     * - cycles_to_pause: Number of cycles after which the simulation pauses.
     * - simulation_over: Flag to end the simulation.
     */
    int size <- 100;
    geometry grid_shape <- rectangle(size, size);
    int cycles <- 0;
    int cycles_to_pause <- 1000;    /* se para a los 1000 ciclos */
    bool simulation_over <- false;

	/**
     * Simulation setup parameters
     * - num_robots: Number of cleaning robots.
     * - num_sensors: Number of environmental sensors.
     * - num_supply_closets: Number of supply closets.
     * - num_charging_stations: Number of charging stations.
     * - dirt_quantity: Number of dirt patches to be generated in the simulation.
     */
    int num_robots <- 1;
    int num_sensors <- 1;
    int num_supply_closets <- 1;
    int num_charging_stations <- 1;
    int dirt_quantity <- 1;
    
    /**
     * Robot-specific attributes
     * - initial_battery: The starting battery level of the robots.
     * - battery_threshold: Minimum battery level before recharging is required.
     * - initial_bags: Initial number of trash bags the robot carries.
     * - initial_detergent: Initial amount of detergent carried by the robot.
     */
    int initial_battery <- 100;
    int battery_threshold <- 20;
    int initial_bags <- 1;
    int initial_detergent <- 100;

    /**
     * Role names for communication and registration in the Directory Facilitator (DF)
     * - Robot_role: Role name for the robots.
     * - Sensor_role: Role name for the sensors.
     * - ChargingStation_role: Role name for the charging stations.
     * - SupplyCloset_role: Role name for the supply closets.
     * - Dirt_role: Role name for dirt patches.
     */
    string Robot_role <- "Robot";
    string Sensor_role <- "Sensor";
    string ChargingStation_role <- "ChargingStation";
    string SupplyCloset_role <- "SupplyCloset";
    string Dirt_role <- "Dirt";

	/**
     * Actions used in communication between agents
     * - sweep_action: Action for the robot to sweep.
     * - mop_action: Action for the robot to mop.
     * - collect_action: Action for the robot to collect dirt.
     * - recharge_action: Action to request battery recharging.
     * - supply_resource_action: Action for supplying resources to the robot.
     */
    string sweep_action <- "Sweep";
    string mop_action <- "Mop";
    string collect_action <- "Collect";
    string recharge_action <- "Recharge";
    string supply_resource_action <- "Supply_Resource";
	
	/**
     * Predicates used in communication messages between agents
     * - dirt_detected: Predicate to indicate dirt has been detected.
     * - resource_needed: Predicate to indicate a resource is needed.
     * - resource_provided: Predicate to indicate a resource has been provided.
     * - resource_not_available: Predicate to indicate a resource is not available.
     * - battery_low: Predicate to indicate the robot's battery is low.
     */
    string dirt_detected <- "Dirt_Detected";
    string resource_needed <- "Resource_Needed";
    string resource_provided <- "Resource_Provided";
    string resource_not_available <- "Resource_Not_Available";
    string battery_low <- "Battery_Low";

	/**
     * Message concept names used in communication
     * - dirt_type: Concept representing the type of dirt.
     * - location_concept: Concept representing a location in the environment.
     * - resource_type: Concept representing the type of resource.
     */
    string dirt_type <- "Dirt_Type";
    string location_concept <- "Location";
    string resource_type <- "Resource_Type";

	/**
     * Initial setup: Creating the agents in the environment
     * - Creates 1 Directory Facilitator (df), charging stations, supply closets, sensors, robots, and dirt patches.
     */
    init {
        create species: df number: 1;
        create species: charging_station number: num_charging_stations;
        create species: supply_closet number: num_supply_closets;
        loop i from: 0 to: 2 {
        	loop j from: 0 to: 3 {
	        create species: environmental_sensor number: 1 {
	            location <- {(16.6666 + i * 33.3333), (16.6666 + j * 33.3333)}; // Ajuste automático de la posición
	        	}
	        }
        }
        create species: cleaning_robot number: num_robots;
        create species: dirt number: dirt_quantity;
    }

	/**
     * Reflex to count the cycles in the simulation.
     * - Increases the cycle count by 1 on each step.
     */
    reflex counting {
        cycles <- cycles + 1;
    }

	/**
     * Reflex to pause the simulation after a specific number of cycles.
     * - Resets the cycle count and pauses the simulation.
     */
    reflex pausing when: cycles = cycles_to_pause {
        cycles <- 0;
        write "Simulación pausada tras " + cycles_to_pause;
        do pause;
    }

	/**
     * Reflex to stop the simulation when the simulation_over flag is set to true.
     */
    reflex halting when: simulation_over {
        write "Finalizando simulación";
        do die;
    }
}


grid my_grid width: size height: size neighbors: 8 {}

/**
 * Species: df (Directory Facilitator)
 * Description:
 * Acts as a directory facilitator for registering and searching agents with specific roles.
 * Maintains a list of agents and their associated roles.
 */
species df {
	
	/**
     * Attributes:
     * - yellow_pages: List of pairs where each pair contains a role and an agent.
     */
    list<pair> yellow_pages <- [];
    
    /**
     * Method: register
     * Registers an agent with a specific role in the yellow pages.
     * 
     * @param the_role: The role to register the agent under.
     * @param the_agent: The agent to register.
     * @return registered: Boolean indicating whether the registration was successful.
     */
    bool register(string the_role, agent the_agent) {
        bool registered;
        add the_role::the_agent to: yellow_pages;
        return registered;
    }
    
    /**
     * Method: search
     * Searches for agents registered under a specific role.
     * 
     * @param the_role: The role to search for.
     * @return found_ones: A list of agents registered under the given role.
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
 * Description:
 * Represents a charging station where robots can recharge their batteries.
 * The charging station manages charging requests and informs robots when their batteries are fully recharged.
 */
species charging_station skills: [fipa] control: simple_bdi {
	
	/**
     * Attributes:
     * - station_color: Color used to represent the charging station on the grid (green).
     * - occupied: Boolean indicating whether the station is currently charging a robot.
     * - current_cycle: Counter for the number of cycles remaining to complete charging.
     * - charging_time: Number of cycles required to fully charge a robot.
     * - charging_robot_request: The request message from the robot currently being charged.
     */
    rgb station_color <- rgb("green");
    bool occupied <- false; 
    int current_cycle <- 0;
    int charging_time <- 10;
    message charging_robot_request <- nil;
    
    /**
     * Initialization:
     * - Sets the charging station's location.
     * - Registers the charging station in the DF under the role "ChargingStation".
     */
    init {
        location <- {size / 2 - 5, 5};
        ask df {
            bool registered <- register(ChargingStation_role, myself);
        }
    }
    
    /**
     * Reflex: receive_request
     * Handles incoming charging requests from robots.
     * - If the station is not occupied, it processes the request and begins charging the robot.
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
     * Manages the charging progress for the robot.
     * - Decreases the charging time cycle by cycle.
     * - Once charging is complete, it informs the robot and resets the station's state.
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
     * Visual aspect:
     * - Draws a green square representing the charging station.
     */
    aspect station_aspect {
        draw geometry: square(5) color: station_color;
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("EC") color: #white font:font("Roboto", 20 , #bold) at: pt2;
    }
}

/**
 * Species: supply_closet
 * Description:
 * Represents a supply closet that provides resources such as detergent or trash bags to robots upon request.
 * The closet handles incoming resource requests and sends the appropriate resources back to the requesting robot.
 */
species supply_closet skills: [fipa] control: simple_bdi {
    
    /**
     * Attributes:
     * - closet_color: Color used to represent the supply closet on the grid (orange).
     */
    rgb closet_color <- rgb("orange");

	/**
     * Initialization:
     * - Sets the supply closet's location on the grid.
     * - Registers the supply closet in the DF under the role "SupplyCloset".
     */
    init {
        location <- {size / 2 + 5, 5};
        ask df {
            bool registered <- register(SupplyCloset_role, myself);
        }
    }
    
    /**
     * Reflex: receive_request
     * Handles incoming resource requests from robots.
     * - Processes the request and responds with the requested resource (e.g., detergent, trash bags).
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
     * Visual aspect:
     * - Draws an orange square representing the supply closet on the grid.
     */
    aspect closet_aspect {
        draw geometry: rectangle(10, 4) color: closet_color;
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("AR") color: #white font:font("Roboto", 20 , #bold) at: pt2;
    }
}

/**
 * Species: environmental_sensor
 * Description:
 * Represents an environmental sensor that detects dirt within a certain radius.
 * Sensors report the detection of dirt to the robots for cleaning actions.
 */
species environmental_sensor skills: [fipa] control: simple_bdi {
    
    /**
     * Attributes:
     * - sensor_color: The color used to represent the sensor on the grid (red).
     * - sensor_detection_area_color: The color used to represent the detection area (purple).
     * - sensor_detection_area_border_color:
     * - detection_area: The geometric area (circle) representing the sensor's detection radius.
     */
    rgb sensor_color <- rgb("red");
    rgb sensor_detection_area_color <- rgb("#ffcfcf", 70);   /* light red with transparency*/
    rgb sensor_detection_area_border_color <- rgb("#ff2929", 130);   /* red with transparency*/   /* light red with transparency*/
    geometry detection_area;

	/**
     * Initialization:
     * - Sets the location of the sensor based on predefined fixed points on the grid (corners and center).
     * - Defines a circular detection area for detecting dirt.
     * - Registers the sensor in the DF under the role "Sensor".
     */
    init {
        list<point> fixed_locations <- [
            {5, 5},
            {size - 5, 5},
            {5, size - 5},
            {size - 5, size - 5},
            {size / 2, size / 2}
        ];

        int sensor_index <- (index mod length(fixed_locations));

        location <- fixed_locations at sensor_index;

        float side <- 33.33;
        detection_area <- square(side) translated_by location;

        ask df {
            bool registered <- register(Sensor_role, myself);
        }
    }

	/**
     * Reflex: detect_dirt
     * Continuously monitors for dirt within the sensor's detection area.
     * - If dirt is detected within the defined radius and has not been detected before, the sensor reports it.
     * - The sensor sets a flag to prevent repeated detection of the same dirt patch.
     */
	reflex detect_dirt {
	    list<agent> robots;
	    
	    ask df {
	        robots <- search(Robot_role);
	    }
	    
	    loop dirt_instance over: species(dirt) {
	        point dirt_location <- dirt_instance.location;
	        float distance_to_dirt <- sqrt((location.x - dirt_location.x) ^ 2 + (location.y - dirt_location.y) ^ 2);
	
	        if (distance_to_dirt <= 5.0 and !dirt_instance.already_detected) {
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
	            
	            loop robot over: robots {
	                write "Sensor enviando solicitud de limpieza al robot con ubicación: " + dirt_location;
	                do start_conversation to: [robot] protocol: 'fipa-request' performative: 'request' contents: contents;
	            }
	        }
	    }
	}
	
	/**
     * Reflex: detect_dirt
     * Continuously monitors for dirt within the sensor's detection area.
     * - If dirt is detected within the defined radius and has not been detected before, the sensor reports it.
     * - The sensor sets a flag to prevent repeated detection of the same dirt patch.
     */
      aspect sensor_aspect {
        draw geometry: circle(1) color: sensor_color at: location; // Hacer el sensor pequeño
        draw detection_area color: sensor_detection_area_color border: sensor_detection_area_border_color at: location; // Dibujar el área de detección en la ubicación del sensor
    }
}

/**
 * Species: cleaning_robot
 * Description:
 * Represents a cleaning robot that can perform actions like sweeping, mopping, and collecting dirt.
 * The robot can also request resources from the supply closet and recharge its battery at a charging station.
 */
species cleaning_robot skills: [moving, fipa] control: simple_bdi {
   
   /**
     * Attributes:
     * - robot_color: The color used to represent the robot on the grid (purple).
     * - perceived: Boolean flag indicating whether the robot has perceived something.
     * - speed: The movement speed of the robot.
     * - my_supply_closets: A list of available supply closet agents (found from the DF).
     * - my_charging_stations: A list of available charging station agents (found from the DF).
     */
    rgb robot_color <- rgb("purple");
    bool perceived <- false;
    list<agent> my_supply_closets;
    list<agent> my_charging_stations;

	/**
     * Belief-related attributes:
     * - at_supply_closet: Predicate indicating the robot is at the supply closet.
     * - at_charging_station: Predicate indicating the robot is at the charging station.
     * - resource_needed_belief: Predicate representing the robot's need for a resource (e.g., detergent, trash bags).
     * - battery_low_belief: Predicate representing the robot's belief that its battery is low.
     * - my_supply_closet: Stores the robot's assigned supply closet agent.
     * - my_charging_station: Stores the robot's assigned charging station agent.
     * - battery_level: Stores the robot's current battery level.
     * - bags_quantity: Stores the number of trash bags the robot currently has.
     * - detergent_level: Stores the amount of detergent the robot currently has.
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
     * Predicates for actions the robot performs:
     * - request_resource: Predicate representing the robot's desire to request resources from the supply closet.
     * - request_charge: Predicate representing the robot's desire to request battery recharging at the charging station.
     * - move_to_supply_closet: Predicate representing the robot's desire to move to the supply closet.
     * - move_to_charging_station: Predicate representing the robot's desire to move to the charging station.
     * - move_to_random_location: Predicate representing the robot's desire to move to a random location.
     */
    predicate request_resource <- new_predicate("request_resource");
    predicate request_charge <- new_predicate("request_charge");
    predicate move_to_supply_closet <- new_predicate("move_to_supply_closet");
    predicate move_to_charging_station <- new_predicate("move_to_charging_station");
    predicate move_to_random_location <- new_predicate("move_to_random_location");
    predicate clean_dirt <- new_predicate("clean_dirt");
    
	/**
     * Initialization:
     * - Sets the initial location and movement speed of the robot.
     * - Registers the robot in the DF under the role "Robot".
     * - Searches for supply closets and charging stations in the DF and assigns one of each to the robot.
     * - Initializes the robot's beliefs (battery level, bags quantity, detergent level).
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

		/**
        // Inicializar las necesidades de cada robot
        if (index = 0) {
            // El primer robot necesita cargar la batería
            do add_belief(new_predicate(battery_low_belief));
            do add_desire(move_to_charging_station);  // Agregar deseo de moverse a la estación de carga
        } else if (index = 1) {
            // El segundo robot necesita detergente
            do add_belief(new_predicate(resource_needed_belief, ["type"::"detergent"]));
            do add_desire(move_to_supply_closet);  // Agregar deseo de moverse al armario de repuestos
        }
        */
        
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
     * Handles the robot's request for resources from the supply closet.
     * - If the robot is at the supply closet, it requests the necessary resources (e.g., detergent or trash bags).
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
     * Handles the robot's request for a battery recharge from the charging station.
     * - If the robot is at the charging station, it requests a recharge.
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
     * Moves the robot to the supply closet to collect resources.
     * - The robot moves step by step towards the supply closet's location.
     * - Once at the supply closet, it updates its beliefs and desires to request resources.
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
     * Moves the robot to the charging station to recharge its battery.
     * - The robot moves step by step towards the charging station's location.
     * - Once at the charging station, it updates its beliefs and desires to request recharging.
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
     * Moves the robot to a random location in the environment.
     * - Once it reaches a random point, it stops.
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
	 * Moves the robot to the location of the dirt to clean it.
	 * - The robot retrieves the location of the dirt from its beliefs.
	 * - It calculates the distance to the dirt and moves step by step towards it.
	 * - Once at the dirt's location, the robot cleans the dirt by removing the dirt agent from the simulation.
	 * - After cleaning, it updates its beliefs and removes the desire and intention related to cleaning the dirt.
	 */
	plan move_to_clean_dirt intention: clean_dirt {
	    predicate pred_location <- get_predicate(get_belief(new_predicate("dirt_location")));
	    point dirt_location <- point(pred_location.values["location"]);
	
	    if (dirt_location != nil) {
	        float distance <- sqrt((location.x - dirt_location.x) ^ 2 + (location.y - dirt_location.y) ^ 2);
	
	        if (distance > 0.5) {
	            float step_size <- min(2.0, distance);
	            float direction_x <- (dirt_location.x - location.x) / distance;
	            float direction_y <- (dirt_location.y - location.y) / distance;
	
	            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
	            do goto target: next_step;
	
	        } else {
	            write "Robot llegó a la suciedad en la ubicación " + dirt_location;
	        
            	loop dirt_instance over: species(dirt) {
	                if (dirt_instance.location = dirt_location) {
	                    write "Robot limpia la suciedad en " + dirt_location;
	                    ask dirt_instance {
	                        do die;
	                    }
	                }
                }
                
	            do remove_intention(clean_dirt);
	            do remove_desire(clean_dirt);
	        }
	    } else {
	        write "Error: No se encontró la ubicación de la suciedad en las creencias.";
	    }
	}

	/**
     * Reflex: receive_inform
     * Handles incoming inform messages from other agents.
     * - Updates the robot's beliefs and resources based on the message content (e.g., resource provided, recharge complete).
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
	 * Handles incoming cleaning requests from sensors.
	 * - The robot checks if there are any requests in its message queue.
	 * - If a request is found, it retrieves the location of the dirt from the message.
	 * - The robot then creates a new desire to clean the dirt at the given location.
	 */
    reflex receive_request when: !empty(requests) {
	    message requestMessage <- requests[0];
	    write 'Robot recibe una solicitud de limpieza con contenido ' + requestMessage.contents;
	
	    pair content_pair <- requestMessage.contents[0];
	
	    if (content_pair.key = dirt_detected) {
	        list conceptos_list <- content_pair.value;
	        map conceptos_map <- map(conceptos_list);
	        point dirt_location <- point(conceptos_map[location_concept]);
	        
	        if (dirt_location != nil) {
	            do add_belief(new_predicate("dirt_location", ["location"::dirt_location]));
	            do add_desire(clean_dirt);
	        } else {
	            write "Error: La ubicación de la suciedad es nula.";
	        }
	    }
	}

	/**
     * Visual aspect:
     * - Draws a small purple circle representing the robot on the grid.
     */
    aspect robot_aspect {
        draw circle(2.5) color: robot_color at: location;
    }
}

/**
 * Species: dirt
 * Description:
 * Represents dirt patches of various types (dust, liquid, garbage) in the environment.
 * Dirt patches are randomly placed within the detection range of sensors or at random locations if no sensors exist.
 */
species dirt {
	
	/**
     * Attributes:
     * - type: Represents the type of dirt (dust, liquid, or garbage).
     * - already_detected: Boolean flag indicating whether the dirt has been detected by a sensor.
     * - dirt_color: Color used to represent the dirt on the grid based on its type.
     * - detected_by_sensor: The sensor agent that detected this dirt, if any.
     */
    string type;
    bool already_detected <- false;
    rgb dirt_color;
    agent detected_by_sensor <- nil;

	/**
     * Initialization:
     * - Registers the dirt in the DF under the role "Dirt".
     * - Searches for nearby sensors in the DF and, if found, positions the dirt within the detection radius of a sensor.
     * - If no sensors are present, places the dirt at a random location in the grid.
     * - Assigns a type to the dirt (dust, liquid, or garbage) and sets the corresponding color.
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
            float radius <- 5.0;
            float angle <- rnd(0.0, 2 * #pi);
            float distance <- rnd(0.0, radius);
            float x_offset <- cos(angle) * distance;
            float y_offset <- sin(angle) * distance;
            location <- sensor_location + {x_offset, y_offset};
        } else {
            location <- rnd(point(size - 10, size - 10)) + {5, 5};
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
     * Visual aspect:
     * - Draws a small square representing the dirt on the grid, with the color based on its type.
     */
    aspect name: dirt_aspect {
        draw geometry: square(5) color: dirt_color at: location;
    }
}

/**
 * Experiment: cleaning_simulation
 * Description:
 * The GUI-based simulation where cleaning robots, sensors, supply closets, 
 * and charging stations interact in a grid environment. Robots perform tasks such as 
 * cleaning, requesting resources, and recharging their batteries.
 */
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
