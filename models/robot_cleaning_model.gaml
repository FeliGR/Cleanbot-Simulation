/**
 * Name: test
 * Author: felipeguzmanrod 
 */

model test

/* Insert your model definition here */
// torus:false significa que los extremos del grid no están conectados
global torus: false {
    int size <- 100;
    int cycles <- 0;
    int cycles_to_pause <- 5;
    bool simulation_over <- false;

    // Parámetros de la simulación
    int num_robots <- 5;
    int num_sensors <- 5;
    int initial_battery <- 100;
    int battery_threshold <- 20;
    int initial_bags <- 1;
    int initial_detergent <- 100;
    int dirt_quantity <- 15;

    // Conocimientos compartidos por todos los agentes que pertenecen a la ontología:
    // - Roles:
    string Robot_role <- "Robot";
    string Sensor_role <- "Sensor";
    string ChargingStation_role <- "ChargingStation";
    string SupplyCloset_role <- "SupplyCloset";

    // - Acciones a usar en el contenido de los mensajes:
    string sweep_action <- "Sweep";
    string mop_action <- "Mop";
    string collect_action <- "Collect";
    string recharge_action <- "Recharge";
    string supply_resource_action <- "Supply_Resource";

    // - Predicados a usar en el contenido de los mensajes:
    string dirt_detected <- "Dirt_Detected";
    string resource_needed <- "Resource_Needed";
    string resource_provided <- "Resource_Provided";
    string resource_not_available <- "Resource_Not_Available";
    string battery_low <- "Battery_Low";

    // - Conceptos a enlazar con acciones y predicados de los mensajes:
    string dirt_type <- "Dirt_Type";
    string location_concept <- "Location";
    string resource_type <- "Resource_Type";

    init {
        create species: df number: 1;
        create species: charging_station number: 1;
        create species: supply_closet number: 1;

        // Crear sensores en las cuatro esquinas y en el centro del grid
        create species: environmental_sensor number: 1 {
            location <- {5, 5}; // Esquina inferior izquierda
        }
        create species: environmental_sensor number: 1 {
            location <- {5, size - 5}; // Esquina superior izquierda
        }
        create species: environmental_sensor number: 1 {
            location <- {size - 5, 5}; // Esquina inferior derecha
        }
        create species: environmental_sensor number: 1 {
            location <- {size - 5, size - 5}; // Esquina superior derecha
        }
        create species: environmental_sensor number: 1 {
            location <- {size / 2, size / 2}; // Centro del grid
        }
        
        create species: cleaning_robot number: 1;
        
    }

    reflex counting {
        cycles <- cycles + 1;
    }

    // Permite establecer pausas recurrentes para observar paso a paso el comportamiento del sistema
    reflex pausing when: cycles = cycles_to_pause {
        write "Pausando simulación";
        cycles <- 0;
        do pause;
    }

    // Para terminar la simulación
    reflex halting when: simulation_over {
        write "Finalizando simulación";
        do die;
    }
}

// El grid de celdas con vecinos diagonales
grid my_grid width: size height: size neighbors: 8 {

}

// Directorio facilitador para que los agentes se encuentren por el rol que usaron al registrarse
species df {
    list<pair> yellow_pages <- [];
    // Para registrar un agente según su rol
    bool register(string the_role, agent the_agent) {
        bool registered;
        add the_role::the_agent to: yellow_pages;
        return registered;
    }
    // Para buscar agentes según el rol
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

species charging_station {
    rgb station_color <- rgb("green");

    init {
        location <- {size / 2 - 5, 5};
        ask df {
            bool registered <- register(ChargingStation_role, myself);
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
        
        // Enviar mensaje agree
        do agree message: requestFromRobot contents: requestFromRobot.contents;

        // Analizar el contenido para obtener el tipo de recurso
        list contentlist <- list(requestFromRobot.contents);
        map content_map <- contentlist at 0;
        pair content_pair <- content_map.pairs at 0;
        string accion <- string(content_pair.key);
        list conceptos <- list(content_pair.value);
        map conceptos_map <- conceptos at 0;
        string requested_resource <- string(conceptos_map[resource_type]);
        
        // Siempre tenemos recursos disponibles, enviar mensaje inform
        list contents;
        string predicado <- resource_provided;
        list concept_list <- [];
        pair resource_type_pair <- resource_type::requested_resource;
        pair quantity_pair <- "quantity"::5; // Siempre proporcionamos 5 unidades
        add resource_type_pair to: concept_list;
        add quantity_pair to: concept_list;
        pair content_pair_resp <- predicado::concept_list; // Corrección: 'predicado' en lugar de 'predicate'
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

    aspect sensor_aspect {
        draw geometry: circle(1) color: sensor_color at: location; // Hacer el sensor pequeño
        draw detection_area color: sensor_detection_area_color at: location; // Dibujar el área de detección en la ubicación del sensor
    }
}

species cleaning_robot skills: [moving, fipa] control: simple_bdi {
    // Variables internas
    rgb robot_color <- rgb("orange");
    bool perceived <- false;

    // Creencias del robot
    string at_supply_closet <- "at_fridge";
    string resource_needed_belief <- "resource_needed";
    string my_supply_closet <- "my_supply_closet";
    string battery_level <- "battery_level";
    string bags_quantity <- "bags_quantity";
    string detergent_level <- "detergent_level";
    

    // Deseos del robot
    predicate request_resource <- new_predicate("request_resource");
    predicate move_to_supply_closet <- new_predicate("move_to_supply_closet");
    
    point supply_closet_target;

    list<agent> my_supply_closets;

    init {
        speed <- 10.0;
        location <- rnd(point(size, size));

        // Registro en el df
        ask df {
            bool registered <- register(Robot_role, myself);
            myself.my_supply_closets <- search(SupplyCloset_role);
        }

        // Inicialización de creencias
        do add_belief(new_predicate(battery_level, ["level"::initial_battery]));
        do add_belief(new_predicate(bags_quantity, ["quantity"::initial_bags]));
        do add_belief(new_predicate(detergent_level, ["level"::initial_detergent]));
        
        // Suponiendo que solo hay un armario de repuestos
        if (!empty(my_supply_closets)) {
            do add_belief(new_predicate(my_supply_closet, ["agent"::(my_supply_closets at 0)]));
        }
        
        // Añadir una necesidad de recurso al inicio para disparar la solicitud
        do add_belief(new_predicate(resource_needed_belief, ["type"::"detergent"]));
    }

	// Regla para agregar deseo de moverse cuando necesita un recurso y no está en el armario
    rule beliefs: [new_predicate(resource_needed_belief)] when: !has_belief(new_predicate(at_supply_closet)) new_desire: move_to_supply_closet;
    


    // Plan para solicitar recursos
    plan request_resource intention: request_resource {
    	if (has_belief(new_predicate(at_supply_closet))) {
	        // Obtener el tipo de recurso necesario
	        predicate pred_resource_needed <- get_predicate(get_belief(new_predicate(resource_needed_belief)));
	        string resource_type_needed <- string(pred_resource_needed.values["type"]);
	
	        // Eliminar la creencia de recurso necesario
	        do remove_belief(pred_resource_needed);
	
	        // Obtener el armario de repuestos
	        predicate pred_supply_closet <- get_predicate(get_belief(new_predicate(my_supply_closet)));
	        agent the_supply_closet <- agent(pred_supply_closet.values["agent"]);
	
	        // Crear contenido del mensaje
	        list contents;
	        list concept_list <- [];
	        pair resource_type_pair <- resource_type::resource_type_needed;
	        add resource_type_pair to: concept_list;
	        pair content_pair <- supply_resource_action::concept_list;
	        add content_pair to: contents;
	
	        // Enviar solicitud
	        do start_conversation to: [the_supply_closet] protocol: 'fipa-request' performative: 'request' contents: contents;
	
	        write "Robot solicitando recurso " + resource_type_needed + " al armario de repuestos.";
	
	        // Eliminar intención
	        do remove_intention(request_resource);
	        do remove_desire(request_resource);
        }
    }

	// Plan para moverse hacia el armario de repuestos
	plan move_to_supply_closet intention: move_to_supply_closet {
	    write "Cleaning robot moving from " + location;
	
	    // Obtener la ubicación del armario de repuestos
	    predicate pred_my_supply_closet <- get_predicate(get_belief(new_predicate(my_supply_closet)));
	    agent the_supply_closet <- agent(pred_my_supply_closet.values["agent"]);
	    point target_location <- the_supply_closet.location;
	
	    // Calcular la distancia al objetivo
	    float distance <- sqrt((location.x - target_location.x) ^ 2 + (location.y - target_location.y) ^ 2);
	
	    // Si la distancia es mayor a un pequeño umbral, moverse en pasos hacia el objetivo
	    if (distance > 0.5) {
	        // Determinar la dirección del movimiento
	        float step_size <- min(2.0, distance); // Elige el menor entre la distancia y un paso de tamaño 2
	        float direction_x <- (target_location.x - location.x) / distance;
	        float direction_y <- (target_location.y - location.y) / distance;
	
	        // Calcular el nuevo punto de destino en la dirección del armario
	        point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
	
	        // Mover el robot a este nuevo punto
	        do goto target: next_step;
	
	        write "Cleaning robot moving to " + location;
	        write "with destination to " + next_step + " and target supply closet at " + target_location;
	    } else {
	        // Si está lo suficientemente cerca, se considera que ha llegado al armario
	        do add_belief(new_predicate(at_supply_closet));
	        write "Robot llegó al armario de repuestos.";
	        
	        // Una vez llegado, activar el deseo de solicitar recursos
        	do add_desire(request_resource);
	    }
	
	    // Eliminar intención si ya llegó al objetivo
	    if (has_belief(new_predicate(at_supply_closet))) {
	        do remove_intention(move_to_supply_closet);
	        do remove_desire(move_to_supply_closet);
	    }
	}

    // Reflex para recibir inform del armario
	reflex receive_inform when: !empty(informs) {
	    message informFromSupplyCloset <- informs[0];
	    write 'Robot recibe un mensaje inform del armario de repuestos con contenido ' + informFromSupplyCloset.contents;
	
	    // Extraer el contenido del mensaje correctamente
	    pair content_pair <- informFromSupplyCloset.contents[0];
	    string predicado <- string(content_pair.key);
	    list conceptos_list <- content_pair.value;
	
	    // Convertir la lista de conceptos en un mapa directamente
	    map conceptos_map <- map(conceptos_list);
	
	    // Obtener el tipo de recurso y la cantidad proporcionada
	    string provided_resource <- string(conceptos_map[resource_type]);
	    int provided_quantity <- int(conceptos_map["quantity"]);
	
	    // Actualizar los niveles de recursos del robot
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
	
	    // Mensaje de log para confirmar la cantidad recibida
    	write "Robot recibió " + provided_quantity + " unidades de " + provided_resource + " del armario de repuestos.";
}
	
    aspect robot_aspect {
        // Dibujar el robot como un círculo
        draw circle(3) color: robot_color at: location;
    }
}

species dirt {
    string type;
    bool already_detected <- false;
    rgb dirt_color;

    init {
        // Obtener la lista de sensores
        list<agent> sensors <- [];
        ask df {
            sensors <- search(Sensor_role);
        }

        // Verificar si hay sensores disponibles
        if (!empty(sensors)) {
            // Seleccionar un sensor aleatorio
            agent sensor_agent <- one_of(sensors);
            point sensor_location <- sensor_agent.location;
            // Establecer la ubicación cerca del sensor seleccionado
            location <- sensor_location + rnd(point(-10, 10));
        } else {
            // Si no hay sensores, asignar una ubicación aleatoria dentro del grid
            location <- rnd(point(size - 10, size - 10)) + {5, 5};
        }

        // Asignar el tipo y color de la suciedad
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