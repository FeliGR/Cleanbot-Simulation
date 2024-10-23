/**
 * Name: robot_cleaning_model
 * Author: 
 * 	- Felipe Guzmán Rodríguez
 * 	- Pablo Díaz-Masa Valencia
 *
 * Description:
 * Este modelo simula un entorno donde robots de limpieza, sensores, armarios de repuestos y estaciones de carga interactúan para mantener la limpieza.
 */

model robot_cleaning_model

global torus: false {
	
	/**
     * Parámetros del entorno
     * - size: Tamaño de la cuadrícula (100x100).
     * - cycles: Contador de pasos de la simulación.
     * - total_cycles: Contador total de pasos (no se reinicia).
     * - cycles_to_pause: Ciclos antes de pausar la simulación.
     * - simulation_over: Finaliza la simulación.
     */
    float size <- 100.0;
    geometry grid_shape <- rectangle(size, size);
    int cycles <- 0;
    int total_cycles <- 0;
    int cycles_to_pause <- 100000;    // ciclos para pausar la simulación
    bool simulation_over <- false;

	/**
     * Configuración de la simulación
     * - num_robots: Número de robots.
     * - num_sensors: Número de sensores.
     * - num_supply_closets: Número de armarios de repuestos.
     * - num_charging_stations: Número de estaciones de carga.
     * - dirt_quantity: Cantidad inicial de suciedad.
     */
    int num_robots <- 3;    // número de robots
    int num_sensors <- 1;
    int num_supply_closets <- 1;
    int num_charging_stations <- 1;
    int dirt_quantity <- 3;
    
    // Control de generación de suciedad
    int dirt_generation_interval <- 15;    // 15 queda bien con 4 robots
    int last_dirt_generation <- 0;
    
    /**
     * Radio de detección de los sensores
     * - radius: Alcance de detección de los sensores.
     */
    float radius <- 23.6;   // un valor mayor o igual que 23.58 hace que toda la cuadrícula de 100x100 esté cubierta

    /**
     * Nombres de roles para registro en DF
     * - Robot_role: Rol para robots.
     * - Sensor_role: Rol para sensores.
     * - ChargingStation_role: Rol para estaciones de carga.
     * - SupplyCloset_role: Rol para armarios de repuestos.
     * - Dirt_role: Rol para suciedad.
     */
    string Robot_role <- "Robot";
    string Sensor_role <- "Sensor";
    string ChargingStation_role <- "ChargingStation";
    string SupplyCloset_role <- "SupplyCloset";
    string Dirt_role <- "Dirt";

	/**
     * Acciones de comunicación
     * - sweep_action: El robot barre.
     * - mop_action: El robot friega.
     * - collect_action: El robot recoge suciedad.
     * - recharge_action: Solicita recarga de batería.
     * - supply_resource_action: Solicita recursos.
     */
    string sweep_action <- "Sweep";
    string mop_action <- "Mop";
    string collect_action <- "Collect";
    string recharge_action <- "Recharge";
    string supply_resource_action <- "Supply_Resource";
	
	/**
     * Predicados de comunicación
     * - dirt_detected: Suciedad detectada.
     * - resource_needed: Recurso necesario.
     * - resource_provided: Recurso proporcionado.
     * - battery_low: Batería baja.
     */
    string dirt_detected <- "Dirt_Detected";
    string resource_needed <- "Resource_Needed";
    string resource_provided <- "Resource_Provided";
    string battery_low <- "Battery_Low";

	/**
     * Conceptos de mensajes
     * - dirt_type: Tipo de suciedad.
     * - location_concept: Ubicación de la suciedad.
     * - resource_type: Tipo de recurso.
     */
    string dirt_type <- "Dirt_Type";
    string location_concept <- "Location";
    string resource_type <- "Resource_Type";
  
	/**
     * Configuración inicial: Crea agentes en el entorno
     * - df, estaciones de carga, armarios de repuestos, sensores, robots y suciedad.
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
     * Incrementa los contadores de ciclos en cada paso.
     */
    reflex counting {
        cycles <- cycles + 1;
        total_cycles <- total_cycles + 1;
    }
    
    /**
     * Reflex: generate_dirt
     * Crea suciedad cada cierto número de ciclos.
     */
    reflex generate_dirt {
        if (total_cycles - last_dirt_generation >= dirt_generation_interval) {
            last_dirt_generation <- total_cycles;
            create species: dirt number: 1;
            dirt_quantity <- dirt_quantity + 1;
        }
    }

	/**
     * Reflex: pausing
     * Pausa la simulación después de un número establecido de ciclos.
     */
    reflex pausing when: cycles = cycles_to_pause {
        cycles <- 0;
        write "Simulación pausada tras " + cycles_to_pause;
        do pause;
    }

	/**
     * Reflex: halting
     * Detiene la simulación cuando se establece la bandera.
     */
    reflex halting when: simulation_over {
        write "Finalizando simulación";
        do die;
    }
}

grid my_grid width: size height: size neighbors: 8 {}

/**
 * Species: df (Directory Facilitator)
 * Gestiona el registro de agentes y la búsqueda basada en roles.
 */
species df {

    /**
     * Atributos:
     * - yellow_pages: Lista de pares rol-agente.
     */
    list<pair> yellow_pages <- [];
    
    /**
     * Método: register
     * Registra un agente con un rol específico.
     * 
     * @param the_role: Rol para el agente.
     * @param the_agent: Agente a registrar.
     * @return registered: Booleano indicando éxito.
     */
    bool register(string the_role, agent the_agent) {
        bool registered;
        add the_role::the_agent to: yellow_pages;
        return registered;
    }
    
    /**
     * Método: search
     * Encuentra agentes registrados con un rol específico.
     * 
     * @param the_role: Rol a buscar.
     * @return found_ones: Lista de agentes con el rol.
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
 * Gestiona las solicitudes de recarga de batería de los robots.
 */
species charging_station skills: [fipa] control: simple_bdi {
	
    /**
     * Inicialización: Establece la ubicación y registra en el DF.
     */
    init {
        location <- {size / 2 - 5, 45};
        
        ask df {
            bool registered <- register(ChargingStation_role, myself);
        }
    }
    
    /**
     * Reflex: receive_request
     * Responde inmediatamente al robot indicando que la batería ha sido recargada.
     */
    reflex receive_request when: not empty(requests) {
        message requestFromRobot <- requests[0];
        write 'Estación de carga recibe una solicitud del robot con contenido ' + requestFromRobot.contents;
       
        do agree message: requestFromRobot contents: requestFromRobot.contents;

        list contents;
        string predicado <- resource_provided;
        list concept_list <- [];
        pair resource_type_pair <- resource_type::"battery";
        pair quantity_pair <- "quantity"::100;
        add resource_type_pair to: concept_list;
        add quantity_pair to: concept_list;
        pair content_pair_resp <- predicado::concept_list;
        add content_pair_resp to: contents;

        do inform message: requestFromRobot contents: contents;

        write "Estación de carga proporcionó recarga de batería completa al robot.";
    }
    
	/**
     * Aspecto visual: Cuadrado verde para la estación de carga.
     */
    aspect station_aspect {
        draw geometry: square(5) color: rgb("green");
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("EC") color: #white font:font("Roboto", 18 , #bold) at: pt2;
    }
}

/**
 * Species: supply_closet
 * Proporciona recursos (detergente, bolsas de basura) a los robots bajo solicitud.
 */
species supply_closet skills: [fipa] control: simple_bdi {

	/**
     * Inicialización: Establece la ubicación y registra en el DF.
     */
    init {
        location <- {size / 2 + 5, 45};
        ask df {
            bool registered <- register(SupplyCloset_role, myself);
        }
    }
    
    /**
     * Reflex: receive_request
     * Procesa las solicitudes de recursos de los robots.
     */
    reflex receive_request when: not empty(requests) {
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
        
        int provided_quantity <- 5;

        list contents;
        string predicado <- resource_provided;
        list concept_list <- [];
        pair resource_type_pair <- resource_type::requested_resource;
        pair quantity_pair <- "quantity"::provided_quantity;
        add resource_type_pair to: concept_list;
        add quantity_pair to: concept_list;
        pair content_pair_resp <- predicado::concept_list;
        add content_pair_resp to: contents;

        do inform message: requestFromRobot contents: contents;

        write "Armario de repuestos proporcionó " + provided_quantity + " unidades de " + requested_resource + " al robot.";
    }

	/**
     * Aspecto visual: Rectángulo naranja representando el armario de repuestos.
     */
    aspect closet_aspect {
        draw geometry: rectangle(10, 4) color: rgb("orange");
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("AR") color: #white font:font("Roboto", 18 , #bold) at: pt2;
    }
}

/**
 * Species: environmental_sensor
 * Detecta suciedad dentro de un radio y envía solicitudes de limpieza a los robots.
 */
species environmental_sensor skills: [fipa] control: simple_bdi {
    
    /**
     * Inicialización: Registra el sensor en el DF.
     */
    init {
        ask df {
            bool registered <- register(Sensor_role, myself);
        }
    }

	/**
     * Reflex: detect_dirt
     * Detecta suciedad dentro del radio del sensor y la asigna a un robot.
     */
	/**
     * Reflex: detect_dirt
     * Detecta suciedad dentro del radio del sensor y la asigna a un robot.
     */
	reflex detect_dirt {
	    loop dirt_instance over: species(dirt) {
	        point dirt_location <- dirt_instance.location;
	        
	        // Calculate the distance between the sensor and the dirt
	        float distance_to_dirt <- sqrt((location.x - dirt_location.x) ^ 2 + (location.y - dirt_location.y) ^ 2);
	
	        // Only proceed if the dirt is within the sensor's radius and has not been detected yet
	        if (distance_to_dirt <= radius and not dirt_instance.already_detected) {
	
	            if (dirt_instance.assigned_to_robot = nil) {
	                cleaning_robot closest_robot <- nil;
	                float closest_distance <- 1000000.0;   // big number next to infinity
	
	                // Loop over all cleaning robots to find the closest available one
	                loop robot over: species(cleaning_robot) {
	                    // Only consider robots that are not currently busy
	                    if (not robot.cleaning_in_progress and not robot.charging_in_progress) {
	                        // Calculate the distance between the robot and the dirt
	                        float distance_to_robot <- sqrt((robot.location.x - dirt_location.x) ^ 2 + (robot.location.y - dirt_location.y) ^ 2);
	                        
	                        // If this robot is closer than the current closest robot, update the closest_robot and closest_distance
	                        if (distance_to_robot < closest_distance) {
	                            closest_robot <- robot;
	                            closest_distance <- distance_to_robot;
	                        }
	                    }
	                }
	
	                // If a closest robot was found, assign the dirt to this robot
	                if (closest_robot != nil) {
	                    write "El sensor está enviando una solicitud de limpieza a " + closest_robot.name + " para la ubicación: " + dirt_location;
	
	                    list contents;
	                    string predicado <- dirt_detected;
	                    list concept_list <- [];
	
	                    pair dirt_type_pair <- dirt_type::dirt_instance.type;
	                    pair location_pair <- location_concept::dirt_location;
	                    add dirt_type_pair to: concept_list;
	                    add location_pair to: concept_list;
	
	                    pair content_pair_resp <- predicado::concept_list;
	                    add content_pair_resp to: contents;
	
	                    // Send the cleaning request to the closest available robot using FIPA protocol
	                    do start_conversation to: [closest_robot] protocol: 'fipa-request' performative: 'request' contents: contents;
	
	                    // Mark the dirt as detected and assigned
	                    dirt_instance.assigned_to_robot <- closest_robot;
	                    dirt_instance.already_detected <- true;
	                    dirt_instance.detected_by_sensor <- self;
	                }
	            }
	        }
	    }
	}
	
	/**
     * Aspecto visual: Círculo rojo para el sensor y su radio de detección.
     */
    aspect sensor_aspect {
        draw geometry: circle(1) color: rgb("red") at: location; // Representar el sensor pequeño
        draw circle(radius) color: rgb("#ffcfcf", 70) border: rgb("#ff2929", 130) at: location; // Dibujar el área de detección circular
    }
}

/**
 * Species: cleaning_robot
 * Gestiona el movimiento, solicita recursos y limpia la suciedad.
 */
species cleaning_robot skills: [moving, fipa] control: simple_bdi {
   
   /**
     * Atributos:
     * - my_supply_closets: Armarios de repuestos disponibles.
     * - my_charging_stations: Estaciones de carga disponibles.
     * - pending_cleaning_tasks: Lista de tareas de limpieza pendientes.
     * - assigned_dirt_locations: Ubicaciones de suciedad asignadas a este robot.
     * - cleaning_in_progress: Indica si el robot está limpiando actualmente.
     * - charging_in_progress: Indica si el robot está en proceso de recarga.
     */
    list<agent> my_supply_closets;
    list<agent> my_charging_stations;
    list<point> pending_cleaning_tasks <- [];
    list<point> assigned_dirt_locations <- [];
    bool cleaning_in_progress <- false;
    bool charging_in_progress <- false;
    int battery_threshold <- 20;
    int initial_battery <- 100;    // batería inicial: no tiene por qué ser 100
    int initial_bags <- 5;
    int initial_detergent <- 100;
    
    /**
     * Atributos de creencias
     * - Almacena creencias sobre ubicación, batería, recursos y agentes asignados.
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
     * Predicados: Acciones y deseos para solicitudes de recursos y movimiento.
     */
    predicate request_resource <- new_predicate("request_resource");
    predicate request_charge <- new_predicate("request_charge");
    predicate move_to_supply_closet <- new_predicate("move_to_supply_closet");
    predicate move_to_charging_station <- new_predicate("move_to_charging_station");
    predicate move_to_random_location <- new_predicate("move_to_random_location");
    predicate clean_dirt <- new_predicate("clean_dirt");
    
    /**
     * Inicialización: Establece ubicación, velocidad y registra el robot en el DF.
     * También inicializa las creencias del robot (batería, recursos).
     */
    init {
        speed <- 2.0;
        location <- rnd(point(size, size));

        ask df {
            bool registered <- register(Robot_role, myself);
            myself.my_supply_closets <- search(SupplyCloset_role);
            myself.my_charging_stations <- search(ChargingStation_role);
        }

        do add_belief(new_predicate(battery_level, ["level"::initial_battery]));
        do add_belief(new_predicate(bags_quantity, ["quantity"::initial_bags]));
        do add_belief(new_predicate(detergent_level, ["level"::initial_detergent]));

        if (not empty(my_supply_closets)) {
            do add_belief(new_predicate(my_supply_closet, ["agent"::(my_supply_closets at 0)]));
        }
        if (not empty(my_charging_stations)) {
            do add_belief(new_predicate(my_charging_station, ["agent"::(my_charging_stations at 0)]));
        }
    }

    /**
     * Regla: Moverse al armario de repuestos cuando se necesita un recurso.
     */
    rule beliefs: [new_predicate(resource_needed_belief)] when: not has_belief(new_predicate(at_supply_closet)) new_desire: move_to_supply_closet;

    /**
     * Regla: Moverse a la estación de carga cuando la batería es baja.
     */
    rule beliefs: [new_predicate(battery_low_belief)] when: not has_belief(new_predicate(at_charging_station)) new_desire: move_to_charging_station;

    /**
     * Regla: Generar deseo de limpiar suciedad cuando hay tareas pendientes.
     */
    rule when: (not empty(pending_cleaning_tasks) and not cleaning_in_progress) new_desire: clean_dirt;

    /**
     * Plan: request_resource
     * Maneja las solicitudes de recursos (detergente o bolsas) si está en el armario de repuestos.
     */
   	plan request_resource intention: request_resource {
    if (has_belief(new_predicate(at_supply_closet))) {
        if (has_belief(new_predicate(resource_needed_belief))) {
            predicate pred_resource_needed <- get_predicate(get_belief(new_predicate(resource_needed_belief)));
            string resource_type_needed <- string(pred_resource_needed.values["type"]);
            write "Recurso necesario: " + resource_type_needed;

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

            do remove_belief(new_predicate(resource_needed_belief));
            do remove_intention(request_resource);
            do remove_desire(request_resource);
        } else {
            write "Robot no necesita más recursos. Eliminando la intención de reabastecimiento.";
            do remove_intention(request_resource);
        }
        do remove_belief(new_predicate(at_supply_closet));
    }
}

    /**
     * Plan: request_charge
     * Solicita recarga de batería si está en la estación de carga.
     */
 	plan request_charge intention: request_charge {
    if (has_belief(new_predicate(at_charging_station)) and not charging_in_progress) {
        predicate pred_charging_station <- get_predicate(get_belief(new_predicate(my_charging_station)));
        agent the_charging_station <- agent(pred_charging_station.values["agent"]);

        list contents;
        pair content_pair <- recharge_action::[];
        add content_pair to: contents;

        do start_conversation to: [the_charging_station] protocol: 'fipa-request' performative: 'request' contents: contents;
        write "\n";
        write "Robot solicitando recarga de batería a la estación de carga.";

        charging_in_progress <- true;

        do remove_belief(new_predicate(battery_low_belief));
        //do remove_intention(request_charge);
        //do remove_desire(request_charge);
    }
}
 	
    /**
     * Plan: move_to_supply_closet
     * Mueve el robot al armario de repuestos para solicitar recursos.
     */
    plan move_to_supply_closet intention: move_to_supply_closet {
    	predicate pred_battery <- get_predicate(get_belief(new_predicate(battery_level)));
    	int current_battery <- int(pred_battery.values["level"]);
    	
        if (charging_in_progress) {
            return;
        }

        predicate pred_my_supply_closet <- get_predicate(get_belief(new_predicate(my_supply_closet)));
        agent the_supply_closet <- agent(pred_my_supply_closet.values["agent"]);
        point target_location <- the_supply_closet.location;

        float distance <- sqrt((location.x - target_location.x) ^ 2 + (location.y - target_location.y) ^ 2);

        if (distance > 0.5) {
            float step_size <- min(speed, distance);
            float direction_x <- (target_location.x - location.x) / distance;
            float direction_y <- (target_location.y - location.y) / distance;

            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
            do goto target: next_step;
            
            current_battery <- current_battery - 1;
            do remove_belief(pred_battery);
	        do add_belief(new_predicate(battery_level, ["level"::current_battery]));
	        
        } else {
            do add_belief(new_predicate(at_supply_closet));
            do add_desire(request_resource);
            do remove_intention(move_to_supply_closet);
            do remove_desire(move_to_supply_closet);
        }
    }

    /**
     * Plan: move_to_charging_station
     * Mueve el robot a la estación de carga.
     */
    plan move_to_charging_station intention: move_to_charging_station {
    	predicate pred_battery <- get_predicate(get_belief(new_predicate(battery_level)));
    	int current_battery <- int(pred_battery.values["level"]);
    	
        if (charging_in_progress) {
            return;
        }

        predicate pred_my_charging_station <- get_predicate(get_belief(new_predicate(my_charging_station)));
        agent the_charging_station <- agent(pred_my_charging_station.values["agent"]);
        point target_location <- the_charging_station.location;

        float distance <- sqrt((location.x - target_location.x) ^ 2 + (location.y - target_location.y) ^ 2);

        if (distance > 0.5) {
            float step_size <- min(speed, distance);
            float direction_x <- (target_location.x - location.x) / distance;
            float direction_y <- (target_location.y - location.y) / distance;

            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
            do goto target: next_step;
            
            current_battery <- current_battery - 1;
            do remove_belief(pred_battery);
	        do add_belief(new_predicate(battery_level, ["level"::current_battery]));

        } else {
            do add_belief(new_predicate(at_charging_station));
            do add_desire(request_charge);
            do remove_intention(move_to_charging_station);
            do remove_desire(move_to_charging_station);
        }
    }

    /**
     * Plan: move_to_clean_dirt
     * Mueve el robot a la ubicación de suciedad y la limpia.
     */	
	plan move_to_clean_dirt intention: clean_dirt {
	    if (charging_in_progress) {
	        return;
	    }
	
	    if (not empty(pending_cleaning_tasks)) {
	        predicate pred_battery <- get_predicate(get_belief(new_predicate(battery_level)));
	        int current_battery <- int(pred_battery.values["level"]);
	        
	        // obtener distancia a la estación de carga
	        predicate pred_my_charging_station <- get_predicate(get_belief(new_predicate(my_charging_station)));
	        agent the_charging_station <- agent(pred_my_charging_station.values["agent"]);
	        point charging_station_location <- the_charging_station.location;
	
	        // Calculate the distance to the charging station
	        float distance_to_charging_station <- sqrt((location.x - charging_station_location.x) ^ 2 + (location.y - charging_station_location.y) ^ 2);
	
	        // Calculate how many movement steps are needed to reach the charging station
	        int steps_needed <- int(ceil(distance_to_charging_station / speed));  // round up to the nearest step
	        
	        if (steps_needed >= current_battery - 2) {    // si va a quedar demasiado lejos de la estación de carga al avanzar un step más
	            do add_belief(new_predicate(battery_low_belief));
	            do add_desire(move_to_charging_station);
	            do remove_intention(clean_dirt);
	            cleaning_in_progress <- false;
	            return;
	        }
	
	        point dirt_location <- pending_cleaning_tasks[0];
	
	        float distance <- sqrt((location.x - dirt_location.x) ^ 2 + (location.y - dirt_location.y) ^ 2);
	
	        if (distance > 0.5) {
	            float step_size <- min(speed, distance);
	            float direction_x <- (dirt_location.x - location.x) / distance;
	            float direction_y <- (dirt_location.y - location.y) / distance;
	
	            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
	            do goto target: next_step;
	
	            current_battery <- current_battery - 1;
	            do remove_belief(pred_battery);
	            do add_belief(new_predicate(battery_level, ["level"::current_battery]));
	
	            //if (current_battery <= battery_threshold and not has_belief(new_predicate(battery_low_belief))) {   // Esto hace falta??
	            //    do add_belief(new_predicate(battery_low_belief));
	            //    do add_desire(move_to_charging_station);
	            //}
	
	            if (current_battery <= 0) {
	                do remove_intention(clean_dirt);
	                cleaning_in_progress <- false;
	                return;
	            }
	
	        } else {
	            write "El robot limpia la suciedad en " + dirt_location;
	            write "\n";
	            loop dirt_instance over: species(dirt) {
	                if (dirt_instance.location = dirt_location) {
	                    ask dirt_instance {
	                        do die;
	                    }
	                    dirt_quantity <- dirt_quantity - 1;
	                    break;
	                }
	            }
	
	            remove dirt_location from: pending_cleaning_tasks;
	            do remove_intention(clean_dirt);
	            cleaning_in_progress <- false;
	
	            current_battery <- current_battery - 1;
	            do remove_belief(pred_battery);
	            do add_belief(new_predicate(battery_level, ["level"::current_battery]));
	
	            if (current_battery <= battery_threshold and not has_belief(new_predicate(battery_low_belief))) {   // Esto hace falta??
	                do add_belief(new_predicate(battery_low_belief));
	                do add_desire(move_to_charging_station);
	            }
	        }
	    } else {
	        cleaning_in_progress <- false;
	        do remove_intention(clean_dirt);
	    }
	}
	
    /**
     * Reflex: receive_inform
     * Actualiza las creencias y recursos del robot basándose en mensajes inform recibidos.
     */
	reflex receive_inform when: not empty(informs) {
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
	            write "Robot actualizó su nivel de detergente a " + current_detergent;
	
	            do remove_belief(new_predicate(at_supply_closet));
	            do remove_intention(request_resource);
	            do remove_desire(request_resource);
	            
	        } else if (provided_resource = "trash_bags") {
	            predicate pred_bags <- get_predicate(get_belief(new_predicate(bags_quantity)));
	            int current_bags <- int(pred_bags.values["quantity"]);
	            current_bags <- current_bags + provided_quantity;
	            do remove_belief(pred_bags);
	            do add_belief(new_predicate(bags_quantity, ["quantity"::current_bags]));
	            write "Robot actualizó su cantidad de bolsas a " + current_bags;
	
	            do remove_belief(new_predicate(at_supply_closet));
	            do remove_intention(request_resource);
	            do remove_desire(request_resource);
	            
	        } else if (provided_resource = "battery") {
	            predicate pred_battery <- get_predicate(get_belief(new_predicate(battery_level)));
	            do remove_belief(pred_battery);
	            do add_belief(new_predicate(battery_level, ["level"::initial_battery]));
	            write "Robot ha completado la recarga de batería. Nivel de batería: " + initial_battery;
	            write "\n";
	
	            do remove_belief(new_predicate(battery_low_belief));
	            do remove_belief(new_predicate(at_charging_station));
	            do remove_intention(request_charge);
	            do remove_desire(request_charge);
	            charging_in_progress <- false;
	        }
	
	        if (not empty(pending_cleaning_tasks) and not cleaning_in_progress) {
	            cleaning_in_progress <- true;
	            do add_desire(clean_dirt);
	        }
	    }
	}
	
    /**
     * Reflex: receive_request
     * Procesa solicitudes de limpieza entrantes y las agrega a la lista de tareas si la suciedad está asignada a este robot.
     */
    reflex receive_request when: not empty(requests) {
        message requestMessage <- requests[0];
        pair content_pair <- requestMessage.contents[0];

        if (content_pair.key = dirt_detected) {
            list conceptos_list <- content_pair.value;
            map conceptos_map <- map(conceptos_list);
            point dirt_location <- point(conceptos_map[location_concept]);

            loop dirt_instance over: species(dirt) {
                if (dirt_instance.location = dirt_location) {
                    if (dirt_instance.assigned_to_robot = self) {
                        if (not (pending_cleaning_tasks contains dirt_location)) {
                            add dirt_location to: pending_cleaning_tasks;
                            write "Robot recibe nueva solicitud de limpieza para la ubicación: " + dirt_location;
                        }
                    }
                }
            }
        }
    }
  	
	/**
     * Aspecto visual: Pequeño círculo morado representando el robot.
     * y su cantidad de batería encima
     */
    aspect robot_aspect {
        draw circle(2.5) color: rgb("purple") at: location;
        
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		// Obtener el nivel de batería desde las creencias del robot
	    if (has_belief(new_predicate(battery_level))) {
	        predicate pred_battery <- get_predicate(get_belief(new_predicate(battery_level)));
	        int current_battery <- int(pred_battery.values["level"]);
	
	        // Dibujar el valor actual de la batería encima del robot
	        draw string(current_battery) color: #white font: font("Roboto", 16, #bold) at: pt2;    // COMENTAR ESTA LÍNEA PARA QUE NO SALGA EL NÚMERO
	    }
    }
}

/**
 * Species: dirt
 * Representa diferentes tipos de suciedad (polvo, líquido, basura) que los sensores detectan.
 */
species dirt {   // NO CAMBIAR GENERACIÓN ALEATORIA DE SUCIEDAD, QUE SI NO SE SALE DEL MAPA

    /**
     * Atributos:
     * - type: Tipo de suciedad (dust, liquid, garbage).
     * - already_detected: Indica si la suciedad ha sido detectada por un sensor.
     * - dirt_color: Color que representa el tipo de suciedad.
     * - detected_by_sensor: Sensor que detectó la suciedad.
     * - assigned_to_robot: Indica el robot asignado para limpiar.
     */
    string type;
    bool already_detected <- false;
    rgb dirt_color;
    agent detected_by_sensor <- nil;
    agent assigned_to_robot <- nil;
	
    /**
     * Inicialización: Registra la suciedad en el DF y la posiciona cerca de un sensor si está disponible.
     */
    init {
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
     * Aspecto visual: Pequeño cuadrado coloreado según el tipo de suciedad.
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
        
        display "cleaning_stats" type: 2d {
        	chart "Cantidad de suciedad" type:series position:{0.0,0.0} size:{1.0,0.5} {
				data "Número de suciedades presentes" value:dirt_quantity color:#grey;
			}
        }
    }
}
