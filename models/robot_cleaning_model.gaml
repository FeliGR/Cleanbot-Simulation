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
    int ciclos_para_pausar <- 5000;
    bool simulacion_finalizada <- false;

	// Parámetros de la Simulación
    int num_robots <- 4 min: 1 max: 10 parameter: true;
    int num_sensors <- 1;
    int num_armarios_repuestos <- 1;
    int num_estaciones_carga <- 1;
    int cantidad_suciedad <- 3;
    list<float> suciedad_acum <- [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   // inicialización de la
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   // cantidad de suciedad
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   // presente en los
    	                          0, 0, 0, 0, 0, 0, 0, 0, 0, 0,   // últimos 50 ciclos
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

/**
 * Especie: sensor
 * - Representa sensores que detectan suciedad y asignan tareas a los robots.
 */
species sensor skills: [fipa] control: simple_bdi {
    
    // Atributo
    int num_suciedades_detectadas <- 0;
    
    /**
     * Inicialización:
     * - Registra el sensor en el DF.
     */
    init {
        ask df {
            bool registrado <- registrar(rol_sensor, myself);
        }
    }

    /**
     * Reflexión: detectar_suciedad
     * - Detecta suciedad en su radio de alcance y asigna tareas a los robots disponibles.
     */
    reflex detectar_suciedad {
        loop instancia_suciedad over: species(suciedad) {
            point ubicacion_suciedad <- instancia_suciedad.location;
            
            float distancia_a_suciedad <- sqrt((location.x - ubicacion_suciedad.x) ^ 2 + (location.y - ubicacion_suciedad.y) ^ 2);

            if (distancia_a_suciedad <= radio and not instancia_suciedad.ya_detectada) {
                num_suciedades_detectadas <- num_suciedades_detectadas + 1;
                if (instancia_suciedad.asignada_a_robot = nil) {
                    robot_limpieza robot_mas_cercano <- nil;
                    float distancia_mas_cercana <- 1000000.0;

                    // Buscar el robot más cercano y disponible
                    loop robot over: species(robot_limpieza) {
                        if (not robot.limpieza_en_progreso and not robot.carga_en_progreso) {
                            float distancia_al_robot <- sqrt((robot.location.x - ubicacion_suciedad.x) ^ 2 + (robot.location.y - ubicacion_suciedad.y) ^ 2);
                            
                            if (distancia_al_robot < distancia_mas_cercana) {
                                robot_mas_cercano <- robot;
                                distancia_mas_cercana <- distancia_al_robot;
                            }
                        }
                    }

                    // Si se encuentra un robot, asignar la tarea
                    if (robot_mas_cercano != nil) {
                        write "El sensor está enviando una solicitud de limpieza a " + robot_mas_cercano.name + " para la ubicación: " + ubicacion_suciedad;

                        // Preparar contenido del mensaje
                        list contenidos;
                        string predicado <- suciedad_detectada;
                        list lista_conceptos <- [];

                        pair par_tipo_suciedad <- tipo_suciedad::instancia_suciedad.type;
                        pair par_ubicacion <- ubicacion_concepto::ubicacion_suciedad;
                        add par_tipo_suciedad to: lista_conceptos;
                        add par_ubicacion to: lista_conceptos;

                        pair par_contenido_resp <- predicado::lista_conceptos;
                        add par_contenido_resp to: contenidos;

                        // Enviar solicitud al robot
                        do start_conversation to: [robot_mas_cercano] protocol: 'fipa-request' performative: 'request' contents: contenidos;

                        // Actualizar estado de la suciedad
                        instancia_suciedad.asignada_a_robot <- robot_mas_cercano;
                        instancia_suciedad.ya_detectada <- true;
                        instancia_suciedad.detectada_por_sensor <- self;
                    }
                }
            }
        }
    }
    
    /**
     * Aspecto visual:
     * - Representa el sensor como un pequeño círculo rojo con un área de detección.
     */
    aspect sensor_aspecto {
        draw geometry: circle(1) color: rgb("red") at: location;
        draw circle(radio) color: rgb("#ffcfcf", 70) border: rgb("#ff2929", 130) at: location;
    }
}

species robot_limpieza skills: [moving, fipa] control: simple_bdi {
   
    // Atributos
    list<agent> mis_armarios_repuestos;
    list<agent> mis_estaciones_carga;
    list<point> tareas_limpieza_pendientes <- [];
    bool limpieza_en_progreso <- false;
    bool carga_en_progreso <- false;
    int umbral_bateria <- 20;
    int bateria_inicial <- 100;
    float speed <- velocidad_robot update: velocidad_robot;

	// Creencias
    string creencia_en_estacion_carga <- "at_estacion_carga";
    string creencia_bateria_baja <- "bateria_low";
    string creencia_estacion_carga <- "my_estacion_carga";
    string creencia_nivel_bateria <- "bateria_level";

	// Deseos e Intenciones
    predicate solicitar_carga <- new_predicate("request_carga");
    predicate mover_a_estacion_carga <- new_predicate("move_to_estacion_carga");
    predicate mover_limpiar_suciedad <- new_predicate("limpiar_suciedad");

	/**
     * Inicialización:
     * - Establece la ubicación inicial, registra el robot en el DF y establece creencias iniciales.
     */
    init {
        location <- rnd(point(tamano, tamano));
        
        ask df {
            bool registrado <- registrar(rol_robot, myself);
            myself.mis_armarios_repuestos <- buscar(rol_armario_repuestos);
            myself.mis_estaciones_carga <- buscar(rol_estacion_carga);
        }

        do add_belief(new_predicate(creencia_nivel_bateria, ["level"::bateria_inicial]));

        if (not empty(mis_estaciones_carga)) {
            do add_belief(new_predicate(creencia_estacion_carga, ["agent"::(mis_estaciones_carga at 0)]));
        }
    }

	/**
     * Reglas BDI:
     * - Generan deseos basados en las creencias actuales.
     */
    rule beliefs: [new_predicate(creencia_bateria_baja)] when: not has_belief(new_predicate(creencia_en_estacion_carga)) new_desire: mover_a_estacion_carga;

    rule when: (not empty(tareas_limpieza_pendientes) and not limpieza_en_progreso) new_desire: mover_limpiar_suciedad;

	/**
     * Plan: solicitar_carga
     * - El robot solicita recarga de batería a la estación de carga.
     */
 	plan solicitar_carga intention: solicitar_carga {
	    if (has_belief(new_predicate(creencia_en_estacion_carga)) and not carga_en_progreso) {
	        predicate pred_estacion_carga <- get_predicate(get_belief(new_predicate(creencia_estacion_carga)));
	        agent la_estacion_carga <- agent(pred_estacion_carga.values["agent"]);
	
	        list contenidos;
	        pair par_contenido <- recargar_accion::[];
	        add par_contenido to: contenidos;
	
	        do start_conversation to: [la_estacion_carga] protocol: 'fipa-request' performative: 'request' contents: contenidos;
	        write "\n";
	        write "Robot solicitando recarga de batería a la estación de carga.";
	
	        carga_en_progreso <- true;
	
	        do remove_belief(new_predicate(creencia_bateria_baja));
	    }
	}
 
 	/**
     * Plan: mover_a_estacion_carga
     * - El robot se mueve hacia la estación de carga.
     */
    plan mover_a_estacion_carga intention: mover_a_estacion_carga {
    	predicate pred_bateria <- get_predicate(get_belief(new_predicate(creencia_nivel_bateria)));
    	int bateria_actual <- int(pred_bateria.values["level"]);
    	
        if (carga_en_progreso) {
            return;
        }

        predicate pred_mi_estacion_carga <- get_predicate(get_belief(new_predicate(creencia_estacion_carga)));
        agent la_estacion_carga <- agent(pred_mi_estacion_carga.values["agent"]);
        point ubicacion_objetivo <- la_estacion_carga.location;

        float distancia <- sqrt((location.x - ubicacion_objetivo.x) ^ 2 + (location.y - ubicacion_objetivo.y) ^ 2);

        if (distancia > 0.5) {
            float tamano_paso <- min(speed, distancia);
            float direccion_x <- (ubicacion_objetivo.x - location.x) / distancia;
            float direccion_y <- (ubicacion_objetivo.y - location.y) / distancia;

            point siguiente_paso <- {location.x + direccion_x * tamano_paso, location.y + direccion_y * tamano_paso};
            do goto target: siguiente_paso;
            
            bateria_actual <- bateria_actual - 1;
            do remove_belief(pred_bateria);
	        do add_belief(new_predicate(creencia_nivel_bateria, ["level"::bateria_actual]));

        } else {
            do add_belief(new_predicate(creencia_en_estacion_carga));
            do add_desire(solicitar_carga);
            do remove_intention(mover_a_estacion_carga);
            do remove_desire(mover_a_estacion_carga);
        }
    }

	/**	
     * Plan: mover_limpiar_suciedad
     * - El robot se mueve hacia la suciedad y la limpia.
     */
	plan mover_a_limpiar_suciedad intention: mover_limpiar_suciedad {
	    if (carga_en_progreso) {
	        return;
	    }
	
	    if (not empty(tareas_limpieza_pendientes)) {
	        predicate pred_bateria <- get_predicate(get_belief(new_predicate(creencia_nivel_bateria)));
	        int bateria_actual <- int(pred_bateria.values["level"]);
	        
	        predicate pred_mi_estacion_carga <- get_predicate(get_belief(new_predicate(creencia_estacion_carga)));
	        agent la_estacion_carga <- agent(pred_mi_estacion_carga.values["agent"]);
	        point ubicacion_estacion_carga <- la_estacion_carga.location;
	
	        float distancia_a_estacion_carga <- sqrt((location.x - ubicacion_estacion_carga.x) ^ 2 + (location.y - ubicacion_estacion_carga.y) ^ 2);
	
	        int pasos_necesarios <- int(ceil(distancia_a_estacion_carga / speed));
	        
	        if (pasos_necesarios >= bateria_actual - 2) {
	            do add_belief(new_predicate(creencia_bateria_baja));
	            do add_desire(mover_a_estacion_carga);
	            do remove_intention(mover_limpiar_suciedad);
	            limpieza_en_progreso <- false;
	            return;
	        }
	
	        point ubicacion_suciedad <- tareas_limpieza_pendientes[0];
	
	        float distancia <- sqrt((location.x - ubicacion_suciedad.x) ^ 2 + (location.y - ubicacion_suciedad.y) ^ 2);
	
	        if (distancia > 0.5) {
	            float tamano_paso <- min(speed, distancia);
	            float direccion_x <- (ubicacion_suciedad.x - location.x) / distancia;
	            float direccion_y <- (ubicacion_suciedad.y - location.y) / distancia;
	
	            point siguiente_paso <- {location.x + direccion_x * tamano_paso, location.y + direccion_y * tamano_paso};
	            do goto target: siguiente_paso;
	
	            bateria_actual <- bateria_actual - 1;
	            do remove_belief(pred_bateria);
	            do add_belief(new_predicate(creencia_nivel_bateria, ["level"::bateria_actual]));
	
	            if (bateria_actual <= umbral_bateria and not has_belief(new_predicate(creencia_bateria_baja))) {   // Esto hace falta??
	                do add_belief(new_predicate(creencia_bateria_baja));
	                do add_desire(mover_a_estacion_carga);
	            }
	
	            if (bateria_actual <= 0) {
	                do remove_intention(mover_limpiar_suciedad);
	                limpieza_en_progreso <- false;
	                return;
	            }
	
	        } else {
	            write "El robot limpia la suciedad en " + ubicacion_suciedad;
	            write "\n";
	            loop suciedad_instance over: species(suciedad) {
	                if (suciedad_instance.location = ubicacion_suciedad) {
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
	
	            remove ubicacion_suciedad from: tareas_limpieza_pendientes;
	            do remove_intention(mover_limpiar_suciedad);
	            limpieza_en_progreso <- false;
	
	            bateria_actual <- bateria_actual - 1;
	            do remove_belief(pred_bateria);
	            do add_belief(new_predicate(creencia_nivel_bateria, ["level"::bateria_actual]));
	
	            if (bateria_actual <= umbral_bateria and not has_belief(new_predicate(creencia_bateria_baja))) {
	                do add_belief(new_predicate(creencia_bateria_baja));
	                do add_desire(mover_a_estacion_carga);
	            }
	        }
	    } else {
	        limpieza_en_progreso <- false;
	        do remove_intention(mover_limpiar_suciedad);
	    }
	}

	/**
     * Reflexión: recibir_informacion
     * - Procesa mensajes inform recibidos, actualizando creencias y recursos.
     */
	reflex recibir_informacion when: not empty(informs) {
	    message mensaje_inform <- informs[0];
	    write 'Robot recibe un mensaje inform con contenido ' + mensaje_inform.contents;
	
	    pair par_contenido <- mensaje_inform.contents[0];
	
	    if (par_contenido.key = recurso_proporcionado) {
	        list lista_conceptos <- par_contenido.value;
	        map mapa_conceptos <- map(lista_conceptos);
	        string recurso_provisto <- string(mapa_conceptos[tipo_recurso]);
	
	        if (recurso_provisto = "bateria") {
	            predicate pred_bateria <- get_predicate(get_belief(new_predicate(creencia_nivel_bateria)));
	            do remove_belief(pred_bateria);
	            do add_belief(new_predicate(creencia_nivel_bateria, ["level"::bateria_inicial]));
	            write "Robot ha completado la recarga de batería. Nivel de batería: " + bateria_inicial;
	            write "\n";
	
	            do remove_belief(new_predicate(creencia_bateria_baja));
	            do remove_belief(new_predicate(creencia_en_estacion_carga));
	            do remove_intention(solicitar_carga);
	            do remove_desire(solicitar_carga);
	            carga_en_progreso <- false;
	        }
	
	        if (not empty(tareas_limpieza_pendientes) and not limpieza_en_progreso) {
	            limpieza_en_progreso <- true;
	            do add_desire(mover_limpiar_suciedad);
	        }
	    }
	}

	/**
     * Reflexión: recibir_solicitud
     * - Procesa solicitudes de limpieza recibidas de los sensores.
     */
    reflex recibir_solicitud when: not empty(requests) {
        message mensaje_solicitud <- requests[0];
        pair par_contenido <- mensaje_solicitud.contents[0];

        if (par_contenido.key = suciedad_detectada) {
            list lista_conceptos <- par_contenido.value;
            map mapa_conceptos <- map(lista_conceptos);
            point ubicacion_suciedad <- point(mapa_conceptos[ubicacion_concepto]);

            loop suciedad_instance over: species(suciedad) {
                if (suciedad_instance.location = ubicacion_suciedad) {
                    if (suciedad_instance.asignada_a_robot = self) {
                        if (not (tareas_limpieza_pendientes contains ubicacion_suciedad)) {
                            add ubicacion_suciedad to: tareas_limpieza_pendientes;
                            write "Robot recibe nueva solicitud de limpieza para la ubicación: " + ubicacion_suciedad;
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Aspecto visual:
     * - Representa el robot como un círculo morado con el nivel de batería.
     */
    aspect robot_aspecto {
        draw circle(2.5) color: rgb("purple") at: location;
        
        point pt <- location;
		point pt2 <- {pt.x-2, pt.y+1};
	    if (has_belief(new_predicate(creencia_nivel_bateria))) {
	        predicate pred_bateria <- get_predicate(get_belief(new_predicate(creencia_nivel_bateria)));
	        int bateria_actual <- int(pred_bateria.values["level"]);
	
	        draw string(bateria_actual) color: #white font: font("Roboto", 16, #bold) at: pt2;
	    }
    }
}

/**
 * Especie: suciedad
 * - Representa diferentes tipos de suciedad que deben ser limpiados.
 */
species suciedad {

    // Atributos
    string type;
    bool ya_detectada <- false;
    rgb color_suciedad;
    agent detectada_por_sensor <- nil;
    agent asignada_a_robot <- nil;

    /**
     * Inicialización:
     * - Asigna un tipo de suciedad y actualiza los contadores globales.
     */
    init {
        type <- one_of(["polvo", "liquido", "basura"]);
        if (type = "polvo") {
            color_suciedad <- rgb("#a6a6a6");
            num_polvo <- num_polvo + 1;
        } else if (type = "liquido") {
            color_suciedad <- rgb("#69a1ff");
            num_liquido <- num_liquido + 1;
        } else if (type = "basura") {
            color_suciedad <- rgb("#aa8222");
            num_basura <- num_basura + 1;
        }
    }

    /**
     * Aspecto visual:
     * - Representa la suciedad como un pequeño cuadrado de color según su tipo en una ubicación aleatoria.
     */
    aspect suciedad_aspecto {
        draw geometry: square(4) color: color_suciedad at: location;
    }
}

/**
 * Experimento: simulacion_limpieza
 * - Define los parámetros y salidas de la simulación.
 */
experiment simulacion_limpieza type: gui {
	
	// Parámetros interactivos
	parameter "Número de robots" var:num_robots category:"Parámetros iniciales";
	parameter "Velocidad de los robots" var:velocidad_robot category:"Parámetros interactivos";
	parameter "Cada cuántos ciclos se genera suciedad" var:intervalo_generacion_suciedad category:"Parámetros interactivos";
	
    output {
        display mapa type: java2D {
            grid mi_cuadricula border: rgb("#C4C4C4");
            species estacion_carga aspect: estacion_aspecto;
            species armario_repuestos aspect: armario_aspecto;
            species sensor aspect: sensor_aspecto;
            species robot_limpieza aspect: robot_aspecto;
            species suciedad aspect: suciedad_aspecto;
        }
        
        display "estadísticas" type: 2d {
        	// Serie temporal
        	chart "Cantidad de suciedad" type:series position:{0.0,0.0} size:{1.0,0.5} {
        		data "Media móvil (50 últimos ciclos)" value:media_suciedad color:#red;
				data "Número de suciedades presentes" value:cantidad_suciedad color:#grey;
			}
			// Gráfico circular
			chart "Tipo de suciedad" type: pie position:{0.5,0.5} size:{0.5,0.5} {
				data "Polvo" value: num_polvo color: rgb("#a6a6a6");
				data "Líquido" value: num_liquido color: rgb("#69a1ff");
				data "Basura" value: num_basura color: rgb("#aa8222");
            }
            // Gráfico de barras
            chart "Suciedad detectada por cada sensor" type:histogram position:{0.0,0.5} size:{0.5,0.5} {
        		data " " value:(sensor collect each.num_suciedades_detectadas) color:rgb("#ffa1a1");
			}
        }
    }
}
