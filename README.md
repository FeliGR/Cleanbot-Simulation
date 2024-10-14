
# Robot Cleaning Model

**Author**: Felipe Guzman Rodriguez

## Description

The **Robot Cleaning Model** simulates an environment where cleaning robots, sensors, supply closets, and charging stations interact to maintain cleanliness. Robots perform various actions such as sweeping, mopping, and collecting dirt. They also interact with supply closets to request resources (e.g., detergent, trash bags) and with charging stations to recharge their batteries when needed.

This model allows users to explore autonomous robotic systems designed for maintenance tasks in environments like households or industrial settings.

## Table of Contents

- [Description](#description)
- [Features](#features)
- [Model Overview](#model-overview)
  - [Species](#species)
  - [Environment Setup](#environment-setup)
  - [Actions and Interactions](#actions-and-interactions)
- [Experiment Setup](#experiment-setup)
- [How to Run](#how-to-run)
- [Customization](#customization)
  - [Parameters](#parameters)
- [Visualization](#visualization)
- [License](#license)

---

## Features

- **Autonomous Robots**: Cleaning robots move around the environment, performing cleaning tasks and managing their resources.
- **Sensors**: Environmental sensors detect dirt and notify robots for cleaning.
- **Supply Closets**: Robots can request resources such as detergent and trash bags from supply closets.
- **Charging Stations**: Robots monitor their battery levels and go to charging stations when needed.
- **Fully Documented**: The model includes comprehensive documentation for all components and interactions.

---

## Model Overview

### Species

The model includes several species that interact within the environment:

1. **Cleaning Robots**: Perform cleaning tasks (sweep, mop, collect dirt) and manage their resources.
2. **Charging Stations**: Provide battery recharge to robots.
3. **Supply Closets**: Provide resources like detergent and trash bags to robots.
4. **Environmental Sensors**: Detect dirt and notify robots for cleaning tasks.
5. **Dirt**: Represents dirt patches (dust, liquid, or garbage) randomly placed in the environment.

### Environment Setup

- The model operates on a **100x100 grid**, where robots, charging stations, supply closets, and sensors are placed.
- **Torus** is disabled, meaning the edges of the grid are boundaries.

### Actions and Interactions

- **Robots** move around the grid, clean dirt, request resources, and recharge batteries.
- **Supply Closets** and **Charging Stations** handle requests from robots for resources and battery recharges.
- **Sensors** detect nearby dirt and inform robots for cleaning actions.

---

## Experiment Setup

The `cleaning_simulation` experiment provides a GUI-based interface where users can observe the simulation. Robots and other agents are visually represented in the grid, with each species assigned a distinct color and shape.

- **Charging Stations**: Green squares.
- **Supply Closets**: Blue squares.
- **Sensors**: Red circles with a purple detection radius.
- **Robots**: Orange circles.
- **Dirt**: Gray, blue, or brown circles depending on the type of dirt.

---

## How to Run

1. Open the **robot_cleaning_model** in your GAMA modeling platform.
2. Choose the `cleaning_simulation` experiment from the dropdown.
3. Press the "Run" button to start the simulation.
4. The grid will display the interactions between robots, supply closets, sensors, and charging stations.

---

## Customization

### Parameters

You can customize the simulation by adjusting the following parameters:

1. **Number of Robots**: Controls how many cleaning robots are present in the simulation.
2. **Initial Battery Level**: Sets the starting battery level for each robot.
3. **Battery Threshold**: Defines when robots should seek recharging.
4. **Initial Trash Bags**: Determines how many trash bags each robot carries initially.
5. **Initial Detergent Level**: Defines how much detergent each robot starts with.

These parameters can be adjusted in the experiment's GUI interface before running the simulation.

---

## Visualization

The experiment output is displayed on a **2D grid** where the environment and agents are rendered. You will observe:

- **Robot Movements**: Robots moving around the grid to clean dirt, request resources, or recharge their batteries.
- **Dirt Detection**: Sensors detecting dirt within their radius and notifying robots for cleaning.
- **Resource Management**: Robots requesting and receiving resources like detergent and trash bags from supply closets.
- **Battery Recharging**: Robots heading to charging stations when their battery level is low.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.
