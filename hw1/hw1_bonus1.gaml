/**
* Name: hw1_bonus1
* Based on the internal empty template.
* 
* This version should be passed with bonus 1
* Author: Flaxen
* Tags: 
*/


model hw1_bonus1

/* Insert your model definition here */

global {
	int numberOfPeople <- 30;
	int numberOfStores <- 5;
	
	int numberOfFoodStores <- 0;
	int numberOfDrinkStores <- 0;
	
	int numberOfInfoCenters <- 1;
	int distanceThreshold <- 2;
	
	init {
		create Guest number:numberOfPeople;
		create Store number:numberOfStores;
		create InfoCenter number:numberOfInfoCenters;
		
		loop counter from: 1 to: numberOfPeople {
			Guest my_agent <- Guest[counter-1];
			my_agent <- my_agent.setName(counter -1);
		}
		
		loop counter from: 1 to: numberOfStores {
			Store my_agent <- Store[counter-1];
			my_agent <- my_agent.setName(counter-1);
		}
		
		loop counter from: 1 to: numberOfInfoCenters {
			InfoCenter my_agent <- InfoCenter[counter-1];
			my_agent <- my_agent.setName(counter-1);
		}
	}
}

species Guest skills: [moving] {
	bool isHungry <- false;
	bool isThirsty <- false;
	string guestName <- "Undefined";
	
	int memorizedFoodStores <- 0;
	int memorizedDrinkStores <- 0;
	
	list memory <- list(Store);
	point targetPoint <- nil;
	Store targetStore <- nil;
	//int counter <- 0;
	
	action setName(int num) {
		guestName <- "Guest " + num;
	}
	
	action pickStoreFromMemory {
		loop while:true {
			int temper <- rnd(1, length(memory)) - 1;
			write "temper = " + temper;
			ask memory[temper] {
				if((myself.isHungry and self.hasFood) or (myself.isThirsty and self.hasDrink)) { 
					return self.location;
				}
			}
			//write "wrong in own memory " + counter;
			//counter <- counter + 1;
		}
	}
	
	aspect base {
		rgb agentColor <- rgb("green");
		
		if(isHungry and isThirsty) {
			agentColor <- rgb("red");
			
		} else if(isThirsty) {
			agentColor <- rgb("darkorange");
			
		} else if(isHungry) {
			agentColor <- rgb("purple");	
			
		}
		
		draw circle(1) color: agentColor;
	}
	
	reflex getHungry when: !isHungry and !isThirsty {
		isHungry <- flip(0.01);
	}
	
	reflex getThirsty when: !isThirsty and !isHungry {
		isThirsty <- flip(0.01);
	}
	
	reflex idle when: targetPoint = nil {
		do wander;
	}
	
	//goto info center when hungry or thirsty
	reflex gotoInfoCenter when: (isHungry or isThirsty) and targetPoint = nil {
		if( ((isHungry and memorizedFoodStores > 0) or (isHungry and memorizedFoodStores)) and flip(0.7)) {
			targetPoint <- pickStoreFromMemory();
		}
		targetPoint <- InfoCenter[0].location;
	}
	
	reflex gotoTargetPoint when: targetPoint != nil {
		do goto target:targetPoint;
	}
	
	reflex askInfoCenter when: !empty(InfoCenter at_distance distanceThreshold) and (isHungry or isThirsty) {
		ask InfoCenter at_distance distanceThreshold {
			
			Store temp <- self.returnStore(myself.isHungry, myself.isThirsty, myself.memory, myself.memorizedFoodStores, myself.memorizedDrinkStores);
			// check if we knew all stores
			// pick from memory in that case
			if(temp = nil) {
				myself.targetPoint <- myself.pickStoreFromMemory();
				break;
				write "does not get here";
			}
			
			myself.targetPoint <- temp.location;
		}
	}
	
	reflex enterStore when: !empty(Store at_distance distanceThreshold) {
		ask Store at_distance distanceThreshold {
			if((myself.isHungry and self.hasFood) or (myself.isThirsty and self.hasDrink)) {
				
				if(!(myself.memory contains self)) {
					add self to: myself.memory;
				}
				
				// increment counter for visited stores
				//add temp to: myself.memory;
				if(myself.isHungry) {
					myself.memorizedFoodStores <- myself.memorizedFoodStores + 1;
				} else {
					myself.memorizedDrinkStores <- myself.memorizedDrinkStores + 1;
				}
				
				myself.isHungry <- false;
				myself.isThirsty <- false;
				myself.targetPoint <- nil;
			}
		}
		
	}
}

species Store {
	bool hasFood;
	bool hasDrink;
	string storeName <- "Undefined";
	
	init {
		if(flip(0.5)) {
			hasFood <- true;
			hasDrink <- false;
			numberOfFoodStores <- numberOfFoodStores + 1;
		} else {
			hasFood <- false;
			hasDrink <- true;
			numberOfDrinkStores <- numberOfDrinkStores + 1;
		}
	}
	
	action setName(int num) {
		storeName <- "Store " + num;
	}
	
	aspect base {
		rgb agentColor <- rgb("lightgray");
		
		if(hasFood and hasDrink) {
			agentColor <- rgb("darkgreen");
		} else if(hasFood) {
			agentColor <- rgb("skyblue");
		} else if(hasDrink) {
			agentColor <- rgb("pink");
		}
		
		draw square(2) color: agentColor;
	}
}

species InfoCenter {
	string infoCenterName <- "Undefined";
	int counter <- 0;
	
	action setName(int num) {
		infoCenterName <- "InfoCenter " + num;
	}
	
	action returnStore(bool isHungry, bool isThirsty, list memory, int memorizedFoodStores, int memorizedDrinkStores) {
		
		// check if guest has visited all stores of drink/food type
		// return nil if thats the case
		if(isHungry and memorizedFoodStores >= numberOfFoodStores) {
			return nil;
		} else if(isThirsty and memorizedDrinkStores >= numberOfDrinkStores) {
			return nil;
		}
		
		// otherwise try to recomment stores
		loop while:true {
			ask Store[rnd(0, numberOfStores-1)] {
				
				write "has memorized " + self.storeName + "?: " + memory contains self + " new memory is " + memory;
				if(!(memory contains self) and ((isHungry and self.hasFood) or (isThirsty and self.hasDrink))) {
					myself.counter <- 0;
					write "recommends " + self.storeName;
					return self;
				}
			}
			write "recommendation does not work while in info " + counter;
			counter <- counter + 1;
		}
	}
	
	aspect base {
		rgb agentColor <- rgb("yellow");
		draw triangle(3) color: agentColor;
	}
}

experiment my_experiment type:gui {
	output {
		display myDisplay {
			species Guest aspect:base;
			species Store aspect:base;
			species InfoCenter aspect:base;
		}
	}
}
