/**
 * Nombre: robot_limpieza_modelo
 * Autores: 
 * 	- Felipe Guzmán Rodríguez
 * 	- Pablo Díaz-Masa Valencia
 *
 * Descripción:
 * Este modelo simula un entorno donde robots de limpieza, sensores, armarios de repuestos y estaciones de carga interactúan para mantener la limpieza.
 */

model robot_limpieza_model

global torus: false {
	
	// Parámetros Globales
    float tamano <- 100.0;
    int ciclos <- 0;
    int ciclos_totales <- 0;
    int ciclos_para_pausar <- 1000000;
    bool simulacion_finalizada <- false;

	// Parámetros de la Simulación
    int num_robots <- 4 min: 1 max: 10 parameter: true;
    int num_sensors <- 1;
    int num_armarios_repuestos <- 1;
    int num_estaciones_carga <- 1;
    int cantidad_suciedad <- 3;
    list<float> suciedad_acum <- [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    	                          
    float media_suciedad <- mean(suciedad_acum); 
    float velocidad_robot <- 2.0 min: 0.1 max: 10.0 parameter: true;
    
    // Contadores de tipos de suciedad
    int num_polvo <- 0;
    int num_liquido <- 0;
    int num_basura <- 0;
    
    int intervalo_generacion_suciedad <- 15;
    int ultima_generacion_suciedad <- 0;

	// Radio de detección de los sensores
    float radio <- 23.6;

	// Roles
    string rol_robot <- "Robot";
    string rol_sensor <- "Sensor";
    string rol_estacion_carga <- "EstacionCarga";
    string rol_armario_repuestos <- "ArmarioRepuestos";

    string recargar_accion <- "Recharge";

	// Conceptos y Predicados
    string suciedad_detectada <- "suciedad_detectada";
    string recurso_proporcionado <- "recurso_Provided";

    string tipo_suciedad <- "suciedad_Type";
    string ubicacion_concepto <- "Location";
    string tipo_recurso <- "recurso_Type";
  
  	/**
     * Inicialización global:
     * - Crea agentes del directorio de facilitación (DF), estaciones de carga, armarios de repuestos, sensores, robots y suciedad.
     */
	init {
		create species: df number: 1;
	    create species: estacion_carga number: num_estaciones_carga;
	    create species: armario_repuestos number: num_armarios_repuestos;

	    loop i from: 0 to: 2 {
	        loop j from: 0 to: 2 {
	            create species: sensor number: 1 {
	                location <- {(tamano / 3) * (i + 0.5), (tamano / 3) * (j + 0.5)};
	            }
	        }
	    }
	    
	    create species: robot_limpieza number: num_robots;
	    create species: suciedad number: cantidad_suciedad;
	}

	/**
     * Reflexión de conteo de ciclos:
     * - Incrementa los contadores de ciclos.
     */
    reflex contar {
        ciclos <- ciclos + 1;
        ciclos_totales <- ciclos_totales + 1;
    }

	/**
     * Reflexión para actualizar la media móvil de suciedad:
     * - Actualiza la lista de suciedad acumulada y calcula la media.
     */
    reflex contador_suciedad_acum {
        suciedad_acum <- suciedad_acum + cantidad_suciedad;
        remove from:suciedad_acum index:0;
        media_suciedad <- mean(suciedad_acum);
    }

	/**
     * Reflexión para generar suciedad:
     * - Genera nueva suciedad en intervalos definidos.
     */
    reflex generar_suciedad {
        if (ciclos_totales - ultima_generacion_suciedad >= intervalo_generacion_suciedad) {
            ultima_generacion_suciedad <- ciclos_totales;
            create species: suciedad number: 1;
            cantidad_suciedad <- cantidad_suciedad + 1;
        }
    }

	/**
     * Reflexión para pausar la simulación:
     * - Pausa la simulación después de un número específico de ciclos.
     */
    reflex pausar when: ciclos = ciclos_para_pausar {
        ciclos <- 0;
        write "Simulación pausada tras " + ciclos_para_pausar;
        do pause;
    }

	/**
     * Reflexión para finalizar la simulación:
     * - Finaliza la simulación cuando se cumple cierta condición.
     */
    reflex finalizar when: simulacion_finalizada {
        write "Finalizando simulación";
        do die;
    }
}

grid mi_cuadricula width: tamano height: tamano neighbors: 8 {}

/**
 * Especie: df (Directorio de Facilitación)
 * - Registra agentes y permite la búsqueda de agentes por rol.
 */
species df {

    list<pair> paginas_amarillas <- [];
    
    /**
     * Método para registrar agentes en el DF.
     */
    bool registrar(string el_rol, agent el_agente) {
        bool registrado;
        add el_rol::el_agente to: paginas_amarillas;
        return registrado;
    }
    
    /**
     * Método para buscar agentes por rol.
     */
    list<agent> buscar(string el_rol) {
        list<agent> encontrados <- [];
        loop candidato over: paginas_amarillas {
            if (candidato.key = el_rol) {
                add item: candidato.value to: encontrados;
            }
        }
        return encontrados;
    }
}

/**
 * Especie: estacion_carga
 * - Representa una estación de carga que puede recargar la batería de los robots.
 */
species estacion_carga skills: [fipa] control: simple_bdi {
	
	/**
     * Inicialización:
     * - Establece la ubicación y registra la estación en el DF.
     */
    init {
        location <- {tamano / 2 - 5, 45};
        
        ask df {
            bool registered <- registrar(rol_estacion_carga, myself);
        }
    }

	/**
     * Reflexión: recibir_solicitud
     * - Procesa solicitudes de recarga de los robots y proporciona la batería.
     */
    reflex recibir_solicitud when: not empty(requests) {
        message solicitud_del_robot <- requests[0];
        write 'Estación de carga recibe una solicitud del robot con contenido ' + solicitud_del_robot.contents;
       
        do agree message: solicitud_del_robot contents: solicitud_del_robot.contents;

        list contenidos;
        string predicado <- recurso_proporcionado;
        list lista_conceptos <- [];
        pair par_tipo_recurso <- tipo_recurso::"bateria";
        pair par_cantidad <- "cantidad"::100;
        add par_tipo_recurso to: lista_conceptos;
        add par_cantidad to: lista_conceptos;
        pair par_contenido_resp <- predicado::lista_conceptos;
        add par_contenido_resp to: contenidos;

        do inform message: solicitud_del_robot contents: contenidos;

        write "Estación de carga proporcionó recarga de batería completa al robot.";
    }

	/**
     * Aspecto visual:
     * - Representa la estación de carga como un cuadrado verde con las iniciales "EC".
     */
    aspect estacion_aspecto {
        draw geometry: square(5) color: rgb("green");
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("EC") color: #white font:font("Roboto", 18 , #bold) at: pt2;
    }
}

/**
 * Especie: armario_repuestos
 * - Representa un armario que proporciona recursos a los robots.
 */
species armario_repuestos skills: [fipa] control: simple_bdi {

	/**
     * Inicialización:
     * - Establece la ubicación y registra el armario en el DF.
     */
    init {
        location <- {tamano / 2 + 5, 45};
        ask df {
            bool registrado <- registrar(rol_armario_repuestos, myself);
        }
    }

	/**
     * Aspecto visual:
     * - Representa el armario como un rectángulo naranja con las iniciales "AR".
     */
    aspect armario_aspecto {
        draw geometry: rectangle(10, 4) color: rgb("orange");
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
		draw string("AR") color: #white font:font("Roboto", 18 , #bold) at: pt2;
    }
}

species sensor skills: [fipa] control: simple_bdi {
	
	int num_suciedades_detectadas <- 0;
    
    init {
        ask df {
            bool registrado <- registrar(rol_sensor, myself);
        }
    }

	reflex detect_suciedad {
	    loop suciedad_instance over: species(suciedad) {
	        point suciedad_location <- suciedad_instance.location;
	        
	        float distance_to_suciedad <- sqrt((location.x - suciedad_location.x) ^ 2 + (location.y - suciedad_location.y) ^ 2);
	
	        if (distance_to_suciedad <= radio and not suciedad_instance.ya_detectada) {
				num_suciedades_detectadas <- num_suciedades_detectadas + 1;
	            if (suciedad_instance.asignada_a_robot = nil) {
	                robot_limpieza closest_robot <- nil;
	                float closest_distance <- 1000000.0;
	
	                loop robot over: species(robot_limpieza) {
	                    if (not robot.limpieza_en_progreso and not robot.carga_en_progreso) {
	                        float distance_to_robot <- sqrt((robot.location.x - suciedad_location.x) ^ 2 + (robot.location.y - suciedad_location.y) ^ 2);
	                        
	                        if (distance_to_robot < closest_distance) {
	                            closest_robot <- robot;
	                            closest_distance <- distance_to_robot;
	                        }
	                    }
	                }
	
	                if (closest_robot != nil) {
	                    write "El sensor está enviando una solicitud de limpieza a " + closest_robot.name + " para la ubicación: " + suciedad_location;
	
	                    list contents;
	                    string predicado <- suciedad_detectada;
	                    list concept_list <- [];
	
	                    pair suciedad_type_pair <- tipo_suciedad::suciedad_instance.type;
	                    pair location_pair <- ubicacion_concepto::suciedad_location;
	                    add suciedad_type_pair to: concept_list;
	                    add location_pair to: concept_list;
	
	                    pair content_pair_resp <- predicado::concept_list;
	                    add content_pair_resp to: contents;
	
	                    do start_conversation to: [closest_robot] protocol: 'fipa-request' performative: 'request' contents: contents;
	
	                    suciedad_instance.asignada_a_robot <- closest_robot;
	                    suciedad_instance.ya_detectada <- true;
	                    suciedad_instance.detectada_por_sensor <- self;
	                }
	            }
	        }
	    }
	}

    aspect sensor_aspect {
        draw geometry: circle(1) color: rgb("red") at: location; // Representar el sensor pequeño
        draw circle(radio) color: rgb("#ffcfcf", 70) border: rgb("#ff2929", 130) at: location; // Dibujar el área de detección circular
    }
}

species robot_limpieza skills: [moving, fipa] control: simple_bdi {
   
    list<agent> my_armarios_repuestos;
    list<agent> my_estaciones_carga;
    list<point> tareas_limpieza_pendientes <- [];
    list<point> assigned_suciedad_locations <- [];
    
    bool limpieza_en_progreso <- false;
    bool carga_en_progreso <- false;
    int bateria_threshold <- 20;
    int initial_bateria <- 100;
    float speed <- velocidad_robot update: velocidad_robot;

    string at_estacion_carga <- "at_estacion_carga";
    string recurso_needed_belief <- "recurso_proporcionado";
    string bateria_low_belief <- "bateria_low";
    string my_estacion_carga <- "my_estacion_carga";
    string bateria_level <- "bateria_level";


    predicate request_carga <- new_predicate("request_carga");
    predicate move_to_estacion_carga <- new_predicate("move_to_estacion_carga");
    predicate limpiar_suciedad <- new_predicate("limpiar_suciedad");

    init {
        location <- rnd(point(tamano, tamano));

        ask df {
            bool registrado <- registrar(rol_robot, myself);
            myself.my_armarios_repuestos <- buscar(rol_armario_repuestos);
            myself.my_estaciones_carga <- buscar(rol_estacion_carga);
        }

        do add_belief(new_predicate(bateria_level, ["level"::initial_bateria]));

        if (not empty(my_estaciones_carga)) {
            do add_belief(new_predicate(my_estacion_carga, ["agent"::(my_estaciones_carga at 0)]));
        }
    }

    rule beliefs: [new_predicate(bateria_low_belief)] when: not has_belief(new_predicate(at_estacion_carga)) new_desire: move_to_estacion_carga;

    rule when: (not empty(tareas_limpieza_pendientes) and not limpieza_en_progreso) new_desire: limpiar_suciedad;

 	plan request_carga intention: request_carga {
	    if (has_belief(new_predicate(at_estacion_carga)) and not carga_en_progreso) {
	        predicate pred_estacion_carga <- get_predicate(get_belief(new_predicate(my_estacion_carga)));
	        agent la_estacion_carga <- agent(pred_estacion_carga.values["agent"]);
	
	        list contents;
	        pair content_pair <- recargar_accion::[];
	        add content_pair to: contents;
	
	        do start_conversation to: [la_estacion_carga] protocol: 'fipa-request' performative: 'request' contents: contents;
	        write "\n";
	        write "Robot solicitando recarga de batería a la estación de carga.";
	
	        carga_en_progreso <- true;
	
	        do remove_belief(new_predicate(bateria_low_belief));
	    }
	}
 
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

	plan move_to_limpiar_suciedad intention: limpiar_suciedad {
	    if (carga_en_progreso) {
	        return;
	    }
	
	    if (not empty(tareas_limpieza_pendientes)) {
	        predicate pred_bateria <- get_predicate(get_belief(new_predicate(bateria_level)));
	        int bateria_actual <- int(pred_bateria.values["level"]);
	        
	        predicate pred_my_estacion_carga <- get_predicate(get_belief(new_predicate(my_estacion_carga)));
	        agent la_estacion_carga <- agent(pred_my_estacion_carga.values["agent"]);
	        point estacion_carga_location <- la_estacion_carga.location;
	
	        float distance_to_estacion_carga <- sqrt((location.x - estacion_carga_location.x) ^ 2 + (location.y - estacion_carga_location.y) ^ 2);
	
	        int steps_necesarios <- int(ceil(distance_to_estacion_carga / speed));
	        
	        if (steps_necesarios >= bateria_actual - 2) {
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
	
	            if (bateria_actual <= bateria_threshold and not has_belief(new_predicate(bateria_low_belief))) {   // Esto hace falta??
	                do add_belief(new_predicate(bateria_low_belief));
	                do add_desire(move_to_estacion_carga);
	            }
	
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
	                    cantidad_suciedad <- cantidad_suciedad - 1;
	                    if (suciedad_instance.type = "polvo") {
				            num_polvo <- num_polvo - 1;
				        } else if (suciedad_instance.type = "liquido") {
				            num_liquido <- num_liquido - 1;
				        } else if (suciedad_instance.type = "basura") {
				            num_basura <- num_basura - 1;
				        }
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
	
	            if (bateria_actual <= bateria_threshold and not has_belief(new_predicate(bateria_low_belief))) {
	                do add_belief(new_predicate(bateria_low_belief));
	                do add_desire(move_to_estacion_carga);
	            }
	        }
	    } else {
	        limpieza_en_progreso <- false;
	        do remove_intention(limpiar_suciedad);
	    }
	}

	reflex receive_inform when: not empty(informs) {
	    message informMessage <- informs[0];
	    write 'Robot recibe un mensaje inform con contenido ' + informMessage.contents;
	
	    pair content_pair <- informMessage.contents[0];
	
	    if (content_pair.key = recurso_proporcionado) {
	        list conceptos_list <- content_pair.value;
	        map conceptos_map <- map(conceptos_list);
	        string recurso_provisto <- string(conceptos_map[tipo_recurso]);
	        int provided_cantidad <- int(conceptos_map["cantidad"]);
	
	        if (recurso_provisto = "bateria") {
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

    reflex receive_request when: not empty(requests) {
        message requestMessage <- requests[0];
        pair content_pair <- requestMessage.contents[0];

        if (content_pair.key = suciedad_detectada) {
            list conceptos_list <- content_pair.value;
            map conceptos_map <- map(conceptos_list);
            point suciedad_location <- point(conceptos_map[ubicacion_concepto]);

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
    
    aspect robot_aspect {
        draw circle(2.5) color: rgb("purple") at: location;
        
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
	    if (has_belief(new_predicate(bateria_level))) {
	        predicate pred_bateria <- get_predicate(get_belief(new_predicate(bateria_level)));
	        int bateria_actual <- int(pred_bateria.values["level"]);
	
	        draw string(bateria_actual) color: #white font: font("Roboto", 16, #bold) at: pt2;
	    }
    }
}

species suciedad {

    string type;
    bool ya_detectada <- false;
    rgb suciedad_color;
    agent detectada_por_sensor <- nil;
    agent asignada_a_robot <- nil;
	
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

    aspect name: suciedad_aspect {
        draw geometry: square(4) color: suciedad_color at: location;
    }
}

experiment simulacion_limpieza type: gui {
	
	parameter "Número de robots" var:num_robots category:"Parámetros iniciales";
	parameter "Velocidad de los robots" var:velocidad_robot category:"Parámetros interactivos";
	parameter "Cada cuántos ciclos se genera suciedad" var:intervalo_generacion_suciedad category:"Parámetros interactivos";
	
    output {
        display mapa type: java2D {
            grid mi_cuadricula border: rgb("#C4C4C4");
            species estacion_carga aspect: estacion_aspecto;
            species armario_repuestos aspect: armario_aspecto;
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
        }
    }
}
