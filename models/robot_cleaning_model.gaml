/**
 * Name: test
 * Author: felipeguzmanrod 
 */

model test

global torus: false {
    int size <- 100;
    int cycles <- 0;
    int cycles_to_pause <- 1;
    bool simulation_over <- false;

    int num_robots <- 5;
    int num_sensors <- 5;
    int initial_battery <- 100;
    int battery_threshold <- 20;
    int initial_bags <- 1;
    int initial_detergent <- 100;
    int dirt_quantity <- 15;

    string Robot_role <- "Robot";
    string Sensor_role <- "Sensor";
    string ChargingStation_role <- "ChargingStation";
    string SupplyCloset_role <- "SupplyCloset";
    string Dirt_role <- "Dirt";

    string sweep_action <- "Sweep";
    string mop_action <- "Mop";
    string collect_action <- "Collect";
    string recharge_action <- "Recharge";
    string supply_resource_action <- "Supply_Resource";

    string dirt_detected <- "Dirt_Detected";
    string resource_needed <- "Resource_Needed";
    string resource_provided <- "Resource_Provided";
    string resource_not_available <- "Resource_Not_Available";
    string battery_low <- "Battery_Low";

    string dirt_type <- "Dirt_Type";
    string location_concept <- "Location";
    string resource_type <- "Resource_Type";

    init {
        create species: df number: 1;
        create species: charging_station number: 1;
        create species: supply_closet number: 1;

        create species: environmental_sensor number: 1 {
            location <- {5, 5};
        }
        
        create species: cleaning_robot number: 2;
        
        create species: dirt number: 3;
        
    }

    reflex counting {
        cycles <- cycles + 1;
    }

    reflex pausing when: cycles = cycles_to_pause {
        write "Pausando simulación";
        cycles <- 0;
        do pause;
    }

    reflex halting when: simulation_over {
        write "Finalizando simulación";
        do die;
    }
}

grid my_grid width: size height: size neighbors: 8 {}

species df {
    list<pair> yellow_pages <- [];
    bool register(string the_role, agent the_agent) {
        bool registered;
        add the_role::the_agent to: yellow_pages;
        return registered;
    }
    
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

species charging_station skills: [fipa] control: simple_bdi {
    rgb station_color <- rgb("green");
    bool occupied <- false;  // Indica si la estación de carga está ocupada
    int tiempo_carga <- 10;  // Tiempo de carga en ciclos
    int current_cycle <- 0;  // Contador de ciclos de carga

    init {
        location <- {size / 2 - 5, 5};
        ask df {
            bool registered <- register(ChargingStation_role, myself);
        }
    }
    
    // Reflex para recibir solicitudes de carga
    reflex receive_request when: !empty(requests) {
        message requestFromRobot <- requests[0];
        write 'Estación de carga recibe una solicitud del robot con contenido ' + requestFromRobot.contents;

        if (!occupied) {
            // Estación disponible, permitir la recarga
            occupied <- true;
            current_cycle <- tiempo_carga; // Inicializamos el ciclo de carga
            do agree message: requestFromRobot contents: requestFromRobot.contents;

            write "Iniciando recarga para el robot.";
            list contents;
            string predicado <- resource_provided;
            list concept_list <- [];
            pair resource_type_pair <- "battery"::"charging";
            add resource_type_pair to: concept_list;
            pair content_pair_resp <- predicado::concept_list;
            add content_pair_resp to: contents;

            // Enviar mensaje inform para confirmar que la recarga ha comenzado
            do inform message: requestFromRobot contents: contents;
        } else {
            // Estación ocupada, rechazar la solicitud
            do refuse message: requestFromRobot contents: requestFromRobot.contents;
            write "Estación de carga está ocupada, rechazando solicitud del robot.";
        }
    }

    // Reflex para gestionar el progreso del ciclo de carga
    reflex charge_progress when: occupied and current_cycle > 0 {
        current_cycle <- current_cycle - 1;  // Reducir el contador de ciclos

        if (current_cycle = 0) {
            // Cuando la carga ha terminado, liberar la estación
            occupied <- false;
            write "Estación de carga ahora está disponible.";
        }
    }

    aspect station_aspect {
        draw geometry: square(5) color: station_color;
    }
}

species supply_closet skills: [fipa] control: simple_bdi {
    rgb closet_color <- rgb("blue");

    init {
        location <- {size / 2 + 5, 5};
        ask df {
            bool registered <- register(SupplyCloset_role, myself);
        }
    }
    
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

    aspect closet_aspect {
        draw geometry: square(5) color: closet_color;
    }
}

species environmental_sensor skills: [fipa] control: simple_bdi {
    rgb sensor_color <- rgb("red");
    rgb sensor_detection_area_color <- rgb("purple");

    geometry detection_area;

    init {
        // Lista de ubicaciones fijas para cada sensor (esquinas y centro)
        list<point> fixed_locations <- [
            {5, 5}, // Esquina superior izquierda
            {size - 5, 5}, // Esquina superior derecha
            {5, size - 5}, // Esquina inferior izquierda
            {size - 5, size - 5}, // Esquina inferior derecha
            {size / 2, size / 2} // Centro
        ];

        // Obtener el índice del sensor basado en la lista de todos los agentes de esta especie
        int sensor_index <- (index mod length(fixed_locations));

        // Asignar la ubicación a cada sensor basándose en su índice
        location <- fixed_locations at sensor_index;

        // Definir un radio fijo para el área de detección
        float radius <- 5.0;
        detection_area <- circle(radius) translated_by location;

        // Registro en el directorio facilitador (DF)
        ask df {
            bool registered <- register(Sensor_role, myself);
        }
    }

reflex detect_dirt {
    loop dirt_instance over: species(dirt) {
        // Calcular la distancia entre el sensor y la suciedad
        point dirt_location <- dirt_instance.location;
        float distance_to_dirt <- sqrt((location.x - dirt_location.x) ^ 2 + (location.y - dirt_location.y) ^ 2);

        // Si la distancia es menor o igual al radio de detección y la suciedad no ha sido detectada antes
        if (distance_to_dirt <= 5.0 and !dirt_instance.already_detected) {  // Radio de 5.0 como el área de detección
            write "¡Suciedad detectada en " + dirt_instance.location + "! Distancia: " + distance_to_dirt;
            dirt_instance.already_detected <- true;
            dirt_instance.detected_by_sensor <- self;

            // Notificar la detección de suciedad
            list contents;
            string predicado <- dirt_detected;
            list concept_list <- [];
            pair dirt_type_pair <- dirt_type::dirt_instance.type;
            pair location_pair <- location_concept::dirt_instance.location;
            add dirt_type_pair to: concept_list;
            add location_pair to: concept_list;
            pair content_pair_resp <- predicado::concept_list;
            add content_pair_resp to: contents;

         

            write "Sensor detectó suciedad de tipo " + dirt_instance.type + " en la ubicación " + dirt_instance.location;
        }
    }
}



    aspect sensor_aspect {
        draw geometry: circle(1) color: sensor_color at: location; // Hacer el sensor pequeño
        draw detection_area color: sensor_detection_area_color at: location; // Dibujar el área de detección en la ubicación del sensor
    }
}




species cleaning_robot skills: [moving, fipa] control: simple_bdi {
    rgb robot_color <- rgb("orange");
    bool perceived <- false;

    string at_supply_closet <- "at_supply_closet";
    string at_charging_station <- "at_charging_station";
    string resource_needed_belief <- "resource_needed";
    string battery_low_belief <- "battery_low";
    string my_supply_closet <- "my_supply_closet";
    string my_charging_station <- "my_charging_station";
    string battery_level <- "battery_level";
    string bags_quantity <- "bags_quantity";
    string detergent_level <- "detergent_level";

    predicate request_resource <- new_predicate("request_resource");
    predicate request_charge <- new_predicate("request_charge");
    predicate move_to_supply_closet <- new_predicate("move_to_supply_closet");
    predicate move_to_charging_station <- new_predicate("move_to_charging_station");
    predicate move_to_random_location <- new_predicate("move_to_random_location");

    point supply_closet_target;
    point charging_station_target;
    list<agent> my_supply_closets;
    list<agent> my_charging_stations;

    init {
        speed <- 10.0;
        location <- rnd(point(size, size));

        // Registro en el df
        ask df {
            bool registered <- register(Robot_role, myself);
            myself.my_supply_closets <- search(SupplyCloset_role);
            myself.my_charging_stations <- search(ChargingStation_role);
        }

        // Inicialización de creencias
        do add_belief(new_predicate(battery_level, ["level"::initial_battery]));
        do add_belief(new_predicate(bags_quantity, ["quantity"::initial_bags]));
        do add_belief(new_predicate(detergent_level, ["level"::initial_detergent]));

        // Suponiendo que solo hay un armario de repuestos y una estación de carga
        if (!empty(my_supply_closets)) {
            do add_belief(new_predicate(my_supply_closet, ["agent"::(my_supply_closets at 0)]));
        }
        if (!empty(my_charging_stations)) {
            do add_belief(new_predicate(my_charging_station, ["agent"::(my_charging_stations at 0)]));
        }

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
        
    }

    rule beliefs: [new_predicate(resource_needed_belief)] when: !has_belief(new_predicate(at_supply_closet)) new_desire: move_to_supply_closet;

    rule beliefs: [new_predicate(battery_low_belief)] when: !has_belief(new_predicate(at_charging_station)) new_desire: move_to_charging_station;

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

    plan request_charge intention: request_charge {
        if (has_belief(new_predicate(at_charging_station))) {
            predicate pred_charging_station <- get_predicate(get_belief(new_predicate(my_charging_station)));
            agent the_charging_station <- agent(pred_charging_station.values["agent"]);

            list contents;
            pair content_pair <- recharge_action::[]; // Acción de recarga sin conceptos adicionales
            add content_pair to: contents;

            do start_conversation to: [the_charging_station] protocol: 'fipa-request' performative: 'request' contents: contents;

            write "Robot solicitando recarga de batería a la estación de carga.";

            do remove_intention(request_charge);
            do remove_desire(request_charge);
        }
    }

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

	plan move_to_random_location intention: move_to_random_location {
	    point random_location <- rnd(point(size, size));
	    do goto target: random_location;
	    
	    write "Robot se movió a una ubicación aleatoria: " + random_location;
	
	    do remove_intention(move_to_random_location);
	    do remove_desire(move_to_random_location);
	}

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

    aspect robot_aspect {
        draw circle(3) color: robot_color at: location;
    }
}

species dirt {
    string type;
    bool already_detected <- false;
    rgb dirt_color;
    agent detected_by_sensor <- nil;

    init {
        list<agent> sensors;
        
        ask df {
            bool registered <- register(Dirt_role, myself);
        }
        
        // Obtener la lista de sensores registrados en el DF
        ask df {
            sensors <- search(Sensor_role);
        }

        if (!empty(sensors)) {
            // Seleccionar aleatoriamente un sensor
            agent sensor_agent <- one_of(sensors);
            point sensor_location <- sensor_agent.location;
            float radius <- 5.0; // Mismo radio que el área de detección del sensor

            // Generar una posición aleatoria dentro del círculo de detección del sensor
            float angle <- rnd(0.0, 2 * #pi);
            float distance <- rnd(0.0, radius);
            float x_offset <- cos(angle) * distance;
            float y_offset <- sin(angle) * distance;
            location <- sensor_location + {x_offset, y_offset};
        } else {
            // Si no hay sensores, ubicar la suciedad aleatoriamente en el mundo
            location <- rnd(point(size - 10, size - 10)) + {5, 5};
        }

        // Asignar tipo y color a la suciedad
        type <- one_of(["dust", "liquid", "garbage"]);
        if (type = "dust") {
            dirt_color <- rgb("gray");
        } else if (type = "liquid") {
            dirt_color <- rgb("blue");
        } else if (type = "garbage") {
            dirt_color <- rgb("brown");
        }
    }

    aspect name: dirt_aspect {
        draw geometry: circle(2) color: dirt_color at: location;
    }
}

experiment cleaning_simulation type: gui {
    output {
        display cleaning_display type: java2D {
            grid my_grid border: rgb("black");
            species charging_station aspect: station_aspect;
            species supply_closet aspect: closet_aspect;
            species environmental_sensor aspect: sensor_aspect;
            species cleaning_robot aspect: robot_aspect;
            species dirt aspect: dirt_aspect;
        }
    }
}