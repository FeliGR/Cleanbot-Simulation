/**
 * Name: robot_limpieza_model
 * Author: 
 * 	- Felipe Guzmán Rodríguez
 * 	- Pablo Díaz-Masa Valencia
 *
 * Description:
 * Este modelo simula un entorno donde robots de limpieza, sensores, armarios de repuestos y estaciones de carga interactúan para mantener la limpieza.
 */

model robot_limpieza_model

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
    int cycles_to_pause <- 1000000;    // ciclos para pausar la simulación
    bool simulation_over <- false;

	/**
     * Configuración de la simulación
     * - num_robots: Número de robots.
     * - num_sensors: Número de sensores.
     * - num_armarios_repuestos: Número de armarios de repuestos.
     * - num_estaciones_carga: Número de estaciones de carga.
     * - cantidad_suciedad: Cantidad inicial de suciedad.
     */
    int num_robots <- 4 min: 1 max: 10 parameter: true;  // parámetro inicial
    //int num_robots <- 4 min: 1 max: 10 parameter: true;    // prueba
    int num_sensors <- 1;
    int num_armarios_repuestos <- 1;
    int num_estaciones_carga <- 1;
    int cantidad_suciedad <- 3;
    list<float> suciedad_acum <- [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // no hemos encontrado una función para generar vectores de ceros
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // y en esta sección no deja implementar loops
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0];  // para el gráfico
    float media_suciedad <- mean(suciedad_acum);                  // para el gráfico
    float robot_speed <- 2.0 min: 0.1 max: 10.0 parameter: true;  // parámetro interactivo
    
    int num_polvo <- 0;    // para los gráficos
    int num_liquido <- 0;  // para los gráficos
    int num_basura <- 0;   // para los gráficos
    
    // Control de generación de suciedad
    int suciedad_generation_interval <- 15;    // 15 queda bien con 4 robots
    int last_suciedad_generation <- 0;
    
    /**
     * Radio de detección de los sensores
     * - radius: Alcance de detección de los sensores.
     */
    float radius <- 23.6;   // un valor mayor o igual que 23.58 hace que toda la cuadrícula de 100x100 esté cubierta

    /**
     * Nombres de roles para registro en DF
     * - Robot_role: Rol para robots.
     * - Sensor_role: Rol para sensores.
     * - EstacionCarga_role: Rol para estaciones de carga.
     * - ArmarioRepuestos_role: Rol para armarios de repuestos.
     * - suciedad_role: Rol para suciedad.
     */
    string Robot_role <- "Robot";
    string Sensor_role <- "Sensor";
    string EstacionCarga_role <- "EstacionCarga";
    string ArmarioRepuestos_role <- "ArmarioRepuestos";
    string suciedad_role <- "suciedad";

	/**
     * Acciones de comunicación
     * - sweep_action: El robot barre.
     * - mop_action: El robot friega.
     * - collect_action: El robot recoge suciedad.
     * - recharge_action: Solicita recarga de batería.
     * - supply_recurso_action: Solicita recursos.
     */
    string sweep_action <- "Sweep";
    string mop_action <- "Mop";
    string collect_action <- "Collect";
    string recharge_action <- "Recharge";
    string supply_recurso_action <- "Supply_recurso";
	
	/**
     * Predicados de comunicación
     * - suciedad_detectada: Suciedad detectada.
     * - recurso_needed: Recurso necesario.
     * - recurso_provided: Recurso proporcionado.
     * - bateria_low: Batería baja.
     */
    string suciedad_detectada <- "suciedad_detectada";
    string recurso_needed <- "recurso_Needed";
    string recurso_provided <- "recurso_Provided";
    string bateria_low <- "bateria_Low";

	/**
     * Conceptos de mensajes
     * - suciedad_type: Tipo de suciedad.
     * - location_concept: Ubicación de la suciedad.
     * - recurso_type: Tipo de recurso.
     */
    string suciedad_type <- "suciedad_Type";
    string location_concept <- "Location";
    string recurso_type <- "recurso_Type";
  
	/**
     * Configuración inicial: Crea agentes en el entorno
     * - df, estaciones de carga, armarios de repuestos, sensores, robots y suciedad.
     */
	 init {
	 	create species: df number: 1;
	    create species: estacion_carga number: num_estaciones_carga;
	    create species: armario_repuestos number: num_armarios_repuestos;

	    loop i from: 0 to: 2 {
	        loop j from: 0 to: 2 {
	            create species: sensor number: 1 {
	                location <- {(size / 3) * (i + 0.5), (size / 3) * (j + 0.5)};
	            }
	        }
	    }
	    
	    create species: robot_limpieza number: num_robots;
	    create species: suciedad number: cantidad_suciedad;
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
     * Reflex: contador_suciedad
     * va actualizando la media móvil
     */
    reflex contador_suciedad_acum {
        suciedad_acum <- suciedad_acum + cantidad_suciedad;      // añadir el nuevo valor de cantidad de suciedad
        remove from:suciedad_acum index:0;                       // eliminar el valor más antiguo
        media_suciedad <- mean(suciedad_acum);                   // calcular la media
    }
    
    /**
     * Reflex: generate_suciedad
     * Crea suciedad cada cierto número de ciclos.
     */
    reflex generate_suciedad {
        if (total_cycles - last_suciedad_generation >= suciedad_generation_interval) {
            last_suciedad_generation <- total_cycles;
            create species: suciedad number: 1;
            cantidad_suciedad <- cantidad_suciedad + 1;
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
 * Species: estacion_carga
 * Gestiona las solicitudes de recarga de batería de los robots.
 */
species estacion_carga skills: [fipa] control: simple_bdi {
	
    /**
     * Inicialización: Establece la ubicación y registra en el DF.
     */
    init {
        location <- {size / 2 - 5, 45};
        
        ask df {
            bool registered <- register(EstacionCarga_role, myself);
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
        string predicado <- recurso_provided;
        list concept_list <- [];
        pair recurso_type_pair <- recurso_type::"bateria";
        pair cantidad_pair <- "cantidad"::100;
        add recurso_type_pair to: concept_list;
        add cantidad_pair to: concept_list;
        pair content_pair_resp <- predicado::concept_list;
        add content_pair_resp to: contents;

        do inform message: requestFromRobot contents: contents;

        write "Estación de carga proporcionó recarga de batería completa al robot.";
    }
    
	/**
     * Aspecto visual: Cuadrado verde para la estación de carga.
     */
    aspect estacion_aspect {
        draw geometry: square(5) color: rgb("green");
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("EC") color: #white font:font("Roboto", 18 , #bold) at: pt2;
    }
}

/**
 * Species: armario_repuestos
 * Proporciona recursos (detergentee, bolsas de basura) a los robots bajo solicitud.
 */
species armario_repuestos skills: [fipa] control: simple_bdi {

	/**
     * Inicialización: Establece la ubicación y registra en el DF.
     */
    init {
        location <- {size / 2 + 5, 45};
        ask df {
            bool registered <- register(ArmarioRepuestos_role, myself);
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
        string requested_recurso <- string(conceptos_map[recurso_type]);
        
        int provided_cantidad <- 5;

        list contents;
        string predicado <- recurso_provided;
        list concept_list <- [];
        pair recurso_type_pair <- recurso_type::requested_recurso;
        pair cantidad_pair <- "cantidad"::provided_cantidad;
        add recurso_type_pair to: concept_list;
        add cantidad_pair to: concept_list;
        pair content_pair_resp <- predicado::concept_list;
        add content_pair_resp to: contents;

        do inform message: requestFromRobot contents: contents;

        write "Armario de repuestos proporcionó " + provided_cantidad + " unidades de " + requested_recurso + " al robot.";
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
 * Species: sensor
 * Detecta suciedad dentro de un radio y envía solicitudes de limpieza a los robots.
 */
species sensor skills: [fipa] control: simple_bdi {
	
	// Atributos
	int num_suciedades_detectadas <- 0;
    
    /**
     * Inicialización: Registra el sensor en el DF.
     */
    init {
        ask df {
            bool registered <- register(Sensor_role, myself);
        }
    }

	/**
     * Reflex: detect_suciedad
     * Detecta suciedad dentro del radio del sensor y la asigna a un robot.
     */
	/**
     * Reflex: detect_suciedad
     * Detecta suciedad dentro del radio del sensor y la asigna a un robot.
     */
	reflex detect_suciedad {
	    loop suciedad_instance over: species(suciedad) {
	        point suciedad_location <- suciedad_instance.location;
	        
	        // Calculate the distance between the sensor and the suciedad
	        float distance_to_suciedad <- sqrt((location.x - suciedad_location.x) ^ 2 + (location.y - suciedad_location.y) ^ 2);
	
	        // Only proceed if the suciedad is within the sensor's radius and has not been detectada yet
	        if (distance_to_suciedad <= radius and not suciedad_instance.ya_detectada) {
				num_suciedades_detectadas <- num_suciedades_detectadas + 1;
	            if (suciedad_instance.asignada_a_robot = nil) {
	                robot_limpieza closest_robot <- nil;
	                float closest_distance <- 1000000.0;   // big number next to infinity
	
	                // Loop over all limpieza robots to find the closest available one
	                loop robot over: species(robot_limpieza) {
	                    // Only consider robots that are not actually busy
	                    if (not robot.limpieza_en_progreso and not robot.carga_en_progreso) {
	                        // Calculate the distance between the robot and the suciedad
	                        float distance_to_robot <- sqrt((robot.location.x - suciedad_location.x) ^ 2 + (robot.location.y - suciedad_location.y) ^ 2);
	                        
	                        // If this robot is closer than the actual closest robot, update the closest_robot and closest_distance
	                        if (distance_to_robot < closest_distance) {
	                            closest_robot <- robot;
	                            closest_distance <- distance_to_robot;
	                        }
	                    }
	                }
	
	                // If a closest robot was found, assign the suciedad to this robot
	                if (closest_robot != nil) {
	                    write "El sensor está enviando una solicitud de limpieza a " + closest_robot.name + " para la ubicación: " + suciedad_location;
	
	                    list contents;
	                    string predicado <- suciedad_detectada;
	                    list concept_list <- [];
	
	                    pair suciedad_type_pair <- suciedad_type::suciedad_instance.type;
	                    pair location_pair <- location_concept::suciedad_location;
	                    add suciedad_type_pair to: concept_list;
	                    add location_pair to: concept_list;
	
	                    pair content_pair_resp <- predicado::concept_list;
	                    add content_pair_resp to: contents;
	
	                    // Send the limpieza request to the closest available robot using FIPA protocol
	                    do start_conversation to: [closest_robot] protocol: 'fipa-request' performative: 'request' contents: contents;
	
	                    // Mark the suciedad as detectada and assigned
	                    suciedad_instance.asignada_a_robot <- closest_robot;
	                    suciedad_instance.ya_detectada <- true;
	                    suciedad_instance.detectada_por_sensor <- self;
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
 * Species: robot_limpieza
 * Gestiona el movimiento, solicita recursos y limpia la suciedad.
 */
species robot_limpieza skills: [moving, fipa] control: simple_bdi {
   
   /**
     * Atributos:
     * - my_armarios_repuestos: Armarios de repuestos disponibles.
     * - my_estaciones_carga: Estaciones de carga disponibles.
     * - tareas_limpieza_pendientes: Lista de tareas de limpieza pendientes.
     * - assigned_suciedad_locations: Ubicaciones de suciedad asignadas a este robot.
     * - limpieza_en_progreso: Indica si el robot está limpiando actualmente.
     * - carga_en_progreso: Indica si el robot está en proceso de recarga.
     */
    list<agent> my_armarios_repuestos;
    list<agent> my_estaciones_carga;
    list<point> tareas_limpieza_pendientes <- [];
    list<point> assigned_suciedad_locations <- [];
    bool limpieza_en_progreso <- false;
    bool carga_en_progreso <- false;
    int bateria_threshold <- 20;
    int initial_bateria <- 100;    // batería inicial: no tiene por qué ser 100
    int initial_bolsas <- 5;
    int initial_detergente <- 100;
    //float speed <- robot_speed;
    float speed <- robot_speed update: robot_speed;   // se actualiza la velocidad si el usuario la ha cambiado
    
    /**
     * Atributos de creencias
     * - Almacena creencias sobre ubicación, batería, recursos y agentes asignados.
     */
    string at_armario_repuestos <- "at_armario_repuestos";
    string at_estacion_carga <- "at_estacion_carga";
    string recurso_needed_belief <- "recurso_needed";
    string bateria_low_belief <- "bateria_low";
    string my_armario_repuestos <- "my_armario_repuestos";
    string my_estacion_carga <- "my_estacion_carga";
    string bateria_level <- "bateria_level";
    string bolsas_cantidad <- "bolsas_cantidad";
    string detergente_level <- "detergente_level";

    /**
     * Predicados: Acciones y deseos para solicitudes de recursos y movimiento.
     */
    predicate request_recurso <- new_predicate("request_recurso");
    predicate request_carga <- new_predicate("request_carga");
    predicate move_to_armario_repuestos <- new_predicate("move_to_armario_repuestos");
    predicate move_to_estacion_carga <- new_predicate("move_to_estacion_carga");
    predicate move_to_random_location <- new_predicate("move_to_random_location");
    predicate limpiar_suciedad <- new_predicate("limpiar_suciedad");
    
    /**
     * Inicialización: Establece ubicación, velocidad y registra el robot en el DF.
     * También inicializa las creencias del robot (batería, recursos).
     */
    init {
        location <- rnd(point(size, size));

        ask df {
            bool registered <- register(Robot_role, myself);
            myself.my_armarios_repuestos <- search(ArmarioRepuestos_role);
            myself.my_estaciones_carga <- search(EstacionCarga_role);
        }

        do add_belief(new_predicate(bateria_level, ["level"::initial_bateria]));
        do add_belief(new_predicate(bolsas_cantidad, ["cantidad"::initial_bolsas]));
        do add_belief(new_predicate(detergente_level, ["level"::initial_detergente]));

        if (not empty(my_armarios_repuestos)) {
            do add_belief(new_predicate(my_armario_repuestos, ["agent"::(my_armarios_repuestos at 0)]));
        }
        if (not empty(my_estaciones_carga)) {
            do add_belief(new_predicate(my_estacion_carga, ["agent"::(my_estaciones_carga at 0)]));
        }
    }

    /**
     * Regla: Moverse al armario de repuestos cuando se necesita un recurso.
     */
    rule beliefs: [new_predicate(recurso_needed_belief)] when: not has_belief(new_predicate(at_armario_repuestos)) new_desire: move_to_armario_repuestos;

    /**
     * Regla: Moverse a la estación de carga cuando la batería es baja.
     */
    rule beliefs: [new_predicate(bateria_low_belief)] when: not has_belief(new_predicate(at_estacion_carga)) new_desire: move_to_estacion_carga;

    /**
     * Regla: Generar deseo de limpiar suciedad cuando hay tareas pendientes.
     */
    rule when: (not empty(tareas_limpieza_pendientes) and not limpieza_en_progreso) new_desire: limpiar_suciedad;

    /**
     * Plan: request_recurso
     * Maneja las solicitudes de recursos (detergentee o bolsas) si está en el armario de repuestos.
     */
   	plan request_recurso intention: request_recurso {
    if (has_belief(new_predicate(at_armario_repuestos))) {
        if (has_belief(new_predicate(recurso_needed_belief))) {
            predicate pred_recurso_needed <- get_predicate(get_belief(new_predicate(recurso_needed_belief)));
            string recurso_type_needed <- string(pred_recurso_needed.values["type"]);
            write "Recurso necesario: " + recurso_type_needed;

            do remove_belief(pred_recurso_needed);
            predicate pred_armario_repuestos <- get_predicate(get_belief(new_predicate(my_armario_repuestos)));
            agent el_armario_repuestos <- agent(pred_armario_repuestos.values["agent"]);

            list contents;
            list concept_list <- [];
            pair recurso_type_pair <- recurso_type::recurso_type_needed;
            add recurso_type_pair to: concept_list;
            pair content_pair <- supply_recurso_action::concept_list;
            add content_pair to: contents;

            do start_conversation to: [el_armario_repuestos] protocol: 'fipa-request' performative: 'request' contents: contents;
            write "Robot solicitando recurso " + recurso_type_needed + " al armario de repuestos.";

            do remove_belief(new_predicate(recurso_needed_belief));
            do remove_intention(request_recurso);
            do remove_desire(request_recurso);
        } else {
            write "Robot no necesita más recursos. Eliminando la intención de reabastecimiento.";
            do remove_intention(request_recurso);
        }
        do remove_belief(new_predicate(at_armario_repuestos));
    }
}

    /**
     * Plan: request_carga
     * Solicita recarga de batería si está en la estación de carga.
     */
 	plan request_carga intention: request_carga {
    if (has_belief(new_predicate(at_estacion_carga)) and not carga_en_progreso) {
        predicate pred_estacion_carga <- get_predicate(get_belief(new_predicate(my_estacion_carga)));
        agent la_estacion_carga <- agent(pred_estacion_carga.values["agent"]);

        list contents;
        pair content_pair <- recharge_action::[];
        add content_pair to: contents;

        do start_conversation to: [la_estacion_carga] protocol: 'fipa-request' performative: 'request' contents: contents;
        write "\n";
        write "Robot solicitando recarga de batería a la estación de carga.";

        carga_en_progreso <- true;

        do remove_belief(new_predicate(bateria_low_belief));
        //do remove_intention(request_carga);
        //do remove_desire(request_carga);
    }
}
 	
    /**
     * Plan: move_to_armario_repuestos
     * Mueve el robot al armario de repuestos para solicitar recursos.
     */
    plan move_to_armario_repuestos intention: move_to_armario_repuestos {
    	predicate pred_bateria <- get_predicate(get_belief(new_predicate(bateria_level)));
    	int bateria_actual <- int(pred_bateria.values["level"]);
    	
        if (carga_en_progreso) {
            return;
        }

        predicate pred_my_armario_repuestos <- get_predicate(get_belief(new_predicate(my_armario_repuestos)));
        agent el_armario_repuestos <- agent(pred_my_armario_repuestos.values["agent"]);
        point target_location <- el_armario_repuestos.location;

        float distance <- sqrt((location.x - target_location.x) ^ 2 + (location.y - target_location.y) ^ 2);

        if (distance > 0.5) {
            float step_size <- min(speed, distance);
            float direction_x <- (target_location.x - location.x) / distance;
            float direction_y <- (target_location.y - location.y) / distance;

            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
            do goto target: next_step;
            
            bateria_actual <- bateria_actual - 1;
            do remove_belief(pred_bateria);
	        do add_belief(new_predicate(bateria_level, ["level"::bateria_actual]));
	        
        } else {
            do add_belief(new_predicate(at_armario_repuestos));
            do add_desire(request_recurso);
            do remove_intention(move_to_armario_repuestos);
            do remove_desire(move_to_armario_repuestos);
        }
    }

    /**
     * Plan: move_to_estacion_carga
     * Mueve el robot a la estación de carga.
     */
    plan move_to_estacion_carga intention: move_to_estacion_carga {
    	predicate pred_bateria <- get_predicate(get_belief(new_predicate(bateria_level)));
    	int bateria_actual <- int(pred_bateria.values["level"]);
    	
        if (carga_en_progreso) {
            return;
        }

        predicate pred_my_estacion_carga <- get_predicate(get_belief(new_predicate(my_estacion_carga)));
        agent la_estacion_carga <- agent(pred_my_estacion_carga.values["agent"]);
        point target_location <- la_estacion_carga.location;

        float distance <- sqrt((location.x - target_location.x) ^ 2 + (location.y - target_location.y) ^ 2);

        if (distance > 0.5) {
            float step_size <- min(speed, distance);
            float direction_x <- (target_location.x - location.x) / distance;
            float direction_y <- (target_location.y - location.y) / distance;

            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
            do goto target: next_step;
            
            bateria_actual <- bateria_actual - 1;
            do remove_belief(pred_bateria);
	        do add_belief(new_predicate(bateria_level, ["level"::bateria_actual]));

        } else {
            do add_belief(new_predicate(at_estacion_carga));
            do add_desire(request_carga);
            do remove_intention(move_to_estacion_carga);
            do remove_desire(move_to_estacion_carga);
        }
    }

    /**
     * Plan: move_to_limpiar_suciedad
     * Mueve el robot a la ubicación de suciedad y la limpia.
     */	
	plan move_to_limpiar_suciedad intention: limpiar_suciedad {
	    if (carga_en_progreso) {
	        return;
	    }
	
	    if (not empty(tareas_limpieza_pendientes)) {
	        predicate pred_bateria <- get_predicate(get_belief(new_predicate(bateria_level)));
	        int bateria_actual <- int(pred_bateria.values["level"]);
	        
	        // obtener distancia a la estación de carga
	        predicate pred_my_estacion_carga <- get_predicate(get_belief(new_predicate(my_estacion_carga)));
	        agent la_estacion_carga <- agent(pred_my_estacion_carga.values["agent"]);
	        point estacion_carga_location <- la_estacion_carga.location;
	
	        // Calculate the distance to the charging estacion
	        float distance_to_estacion_carga <- sqrt((location.x - estacion_carga_location.x) ^ 2 + (location.y - estacion_carga_location.y) ^ 2);
	
	        // Calculate how many movement steps are needed to reach the charging estacion
	        int steps_necesarios <- int(ceil(distance_to_estacion_carga / speed));  // round up to the nearest step
	        
	        if (steps_necesarios >= bateria_actual - 2) {    // si va a quedar demasiado lejos de la estación de carga al avanzar un step más
	            do add_belief(new_predicate(bateria_low_belief));
	            do add_desire(move_to_estacion_carga);
	            do remove_intention(limpiar_suciedad);
	            limpieza_en_progreso <- false;
	            return;
	        }
	
	        point suciedad_location <- tareas_limpieza_pendientes[0];
	
	        float distance <- sqrt((location.x - suciedad_location.x) ^ 2 + (location.y - suciedad_location.y) ^ 2);
	
	        if (distance > 0.5) {
	            float step_size <- min(speed, distance);
	            float direction_x <- (suciedad_location.x - location.x) / distance;
	            float direction_y <- (suciedad_location.y - location.y) / distance;
	
	            point next_step <- {location.x + direction_x * step_size, location.y + direction_y * step_size};
	            do goto target: next_step;
	
	            bateria_actual <- bateria_actual - 1;
	            do remove_belief(pred_bateria);
	            do add_belief(new_predicate(bateria_level, ["level"::bateria_actual]));
	
	            //if (bateria_actual <= bateria_threshold and not has_belief(new_predicate(bateria_low_belief))) {   // Esto hace falta??
	            //    do add_belief(new_predicate(bateria_low_belief));
	            //    do add_desire(move_to_estacion_carga);
	            //}
	
	            if (bateria_actual <= 0) {
	                do remove_intention(limpiar_suciedad);
	                limpieza_en_progreso <- false;
	                return;
	            }
	
	        } else {
	            write "El robot limpia la suciedad en " + suciedad_location;
	            write "\n";
	            loop suciedad_instance over: species(suciedad) {
	                if (suciedad_instance.location = suciedad_location) {
	                	// se actualiza la cantidad de suciedad
	                    cantidad_suciedad <- cantidad_suciedad - 1;
	                    // se actualiza el tipo de la suciedad
	                    if (suciedad_instance.type = "polvo") {
				            num_polvo <- num_polvo - 1;
				        } else if (suciedad_instance.type = "liquido") {
				            num_liquido <- num_liquido - 1;
				        } else if (suciedad_instance.type = "basura") {
				            num_basura <- num_basura - 1;
				        }
				        // se elimina la suciedad
	                    ask suciedad_instance {
	                        do die;
	                    }
	                }
	            }
	
	            remove suciedad_location from: tareas_limpieza_pendientes;
	            do remove_intention(limpiar_suciedad);
	            limpieza_en_progreso <- false;
	
	            bateria_actual <- bateria_actual - 1;
	            do remove_belief(pred_bateria);
	            do add_belief(new_predicate(bateria_level, ["level"::bateria_actual]));
	
	            if (bateria_actual <= bateria_threshold and not has_belief(new_predicate(bateria_low_belief))) {   // Esto hace falta??
	                do add_belief(new_predicate(bateria_low_belief));
	                do add_desire(move_to_estacion_carga);
	            }
	        }
	    } else {
	        limpieza_en_progreso <- false;
	        do remove_intention(limpiar_suciedad);
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
	
	    if (content_pair.key = recurso_provided) {
	        list conceptos_list <- content_pair.value;
	        map conceptos_map <- map(conceptos_list);
	        string recurso_provisto <- string(conceptos_map[recurso_type]);
	        int provided_cantidad <- int(conceptos_map["cantidad"]);
	
	        if (recurso_provisto = "detergente") {
	            predicate pred_detergente <- get_predicate(get_belief(new_predicate(detergente_level)));
	            int actual_detergente <- int(pred_detergente.values["level"]);
	            actual_detergente <- actual_detergente + provided_cantidad;
	            do remove_belief(pred_detergente);
	            do add_belief(new_predicate(detergente_level, ["level"::actual_detergente]));
	            write "Robot actualizó su nivel de detergentee a " + actual_detergente;
	
	            do remove_belief(new_predicate(at_armario_repuestos));
	            do remove_intention(request_recurso);
	            do remove_desire(request_recurso);
	            
	        } else if (recurso_provisto = "trash_bolsas") {
	            predicate pred_bolsas <- get_predicate(get_belief(new_predicate(bolsas_cantidad)));
	            int actual_bolsas <- int(pred_bolsas.values["cantidad"]);
	            actual_bolsas <- actual_bolsas + provided_cantidad;
	            do remove_belief(pred_bolsas);
	            do add_belief(new_predicate(bolsas_cantidad, ["cantidad"::actual_bolsas]));
	            write "Robot actualizó su cantidad de bolsas a " + actual_bolsas;
	
	            do remove_belief(new_predicate(at_armario_repuestos));
	            do remove_intention(request_recurso);
	            do remove_desire(request_recurso);
	            
	        } else if (recurso_provisto = "bateria") {
	            predicate pred_bateria <- get_predicate(get_belief(new_predicate(bateria_level)));
	            do remove_belief(pred_bateria);
	            do add_belief(new_predicate(bateria_level, ["level"::initial_bateria]));
	            write "Robot ha completado la recarga de batería. Nivel de batería: " + initial_bateria;
	            write "\n";
	
	            do remove_belief(new_predicate(bateria_low_belief));
	            do remove_belief(new_predicate(at_estacion_carga));
	            do remove_intention(request_carga);
	            do remove_desire(request_carga);
	            carga_en_progreso <- false;
	        }
	
	        if (not empty(tareas_limpieza_pendientes) and not limpieza_en_progreso) {
	            limpieza_en_progreso <- true;
	            do add_desire(limpiar_suciedad);
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

        if (content_pair.key = suciedad_detectada) {
            list conceptos_list <- content_pair.value;
            map conceptos_map <- map(conceptos_list);
            point suciedad_location <- point(conceptos_map[location_concept]);

            loop suciedad_instance over: species(suciedad) {
                if (suciedad_instance.location = suciedad_location) {
                    if (suciedad_instance.asignada_a_robot = self) {
                        if (not (tareas_limpieza_pendientes contains suciedad_location)) {
                            add suciedad_location to: tareas_limpieza_pendientes;
                            write "Robot recibe nueva solicitud de limpieza para la ubicación: " + suciedad_location;
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
	    if (has_belief(new_predicate(bateria_level))) {
	        predicate pred_bateria <- get_predicate(get_belief(new_predicate(bateria_level)));
	        int bateria_actual <- int(pred_bateria.values["level"]);
	
	        // Dibujar el valor actual de la batería encima del robot
	        draw string(bateria_actual) color: #white font: font("Roboto", 16, #bold) at: pt2;    // COMENTAR ESTA LÍNEA PARA QUE NO SALGA EL NÚMERO
	    }
    }
}

/**
 * Species: suciedad
 * Representa diferentes tipos de suciedad (polvo, líquido, basura) que los sensores detectan.
 */
species suciedad {   // NO CAMBIAR GENERACIÓN ALEATORIA DE SUCIEDAD, QUE SI NO SE SALE DEL MAPA

    /**
     * Atributos:
     * - type: Tipo de suciedad (polvo, liquido, basura).
     * - ya_detectada: Indica si la suciedad ha sido detectada por un sensor.
     * - suciedad_color: Color que representa el tipo de suciedad.
     * - detectada_por_sensor: Sensor que detectó la suciedad.
     * - asignada_a_robot: Indica el robot asignado para limpiar.
     */
    string type;
    bool ya_detectada <- false;
    rgb suciedad_color;
    agent detectada_por_sensor <- nil;
    agent asignada_a_robot <- nil;
	
    /**
     * Inicialización: Registra la suciedad en el DF y la posiciona cerca de un sensor si está disponible.
     */
    init {
        type <- one_of(["polvo", "liquido", "basura"]);
        if (type = "polvo") {
            suciedad_color <- rgb("#a6a6a6");
            num_polvo <- num_polvo + 1;
        } else if (type = "liquido") {
            suciedad_color <- rgb("#69a1ff");
            num_liquido <- num_liquido + 1;
        } else if (type = "basura") {
            suciedad_color <- rgb("#aa8222");
            num_basura <- num_basura + 1;
        }
    }

    /**
     * Aspecto visual: Pequeño cuadrado coloreado según el tipo de suciedad.
     */
    aspect name: suciedad_aspect {
        draw geometry: square(4) color: suciedad_color at: location;
    }
}


experiment simulacion_limpieza type: gui {
	
	parameter "Número de robots" var:num_robots category:"Parámetros iniciales";
	parameter "Velocidad de los robots" var:robot_speed category:"Parámetros interactivos";
	parameter "Cada cuántos ciclos se genera suciedad" var:suciedad_generation_interval category:"Parámetros interactivos";
	
    output {
        display mapa type: java2D {
            grid my_grid border: rgb("#C4C4C4");
            species estacion_carga aspect: estacion_aspect;
            species armario_repuestos aspect: closet_aspect;
            species sensor aspect: sensor_aspect;
            species robot_limpieza aspect: robot_aspect;
            species suciedad aspect: suciedad_aspect;
        }
        
        display "estadísticas" type: 2d {
        	chart "Cantidad de suciedad" type:series position:{0.0,0.0} size:{1.0,0.5} {
        		data "Media móvil (50 últimos ciclos)" value:media_suciedad color:#red;
				data "Número de suciedades presentes" value:cantidad_suciedad color:#grey;
			}
			chart "Tipo de suciedad" type: pie position:{0.5,0.5} size:{0.5,0.5} {
				data "Polvo" value: num_polvo color: rgb("#a6a6a6");
				data "Líquido" value: num_liquido color: rgb("#69a1ff");
				data "Basura" value: num_basura color: rgb("#aa8222");
            }
            chart "Suciedad detectada por cada sensor" type:histogram position:{0.0,0.5} size:{0.5,0.5} {
        		data " " value:(sensor collect each.num_suciedades_detectadas) color:rgb("#ffa1a1");
			}
			// aquí otro chart
        }
    }
}
