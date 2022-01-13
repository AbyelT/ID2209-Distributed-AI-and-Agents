/**
* Name: hw3basict2
* Based on the internal empty template. 
* Author: Flaxen
* Tags: 
*/


model hw3basict2

/* Insert your model definition here */

global {
		
	int numberOfStages <- 4;
	int numberOfGuests <- 20;
	int distanceThreshold <- 2;
	
	int numberOfAttributes <- 6;
	
	
	init {
		create Stage number:numberOfStages;
		create Guest number:numberOfGuests;	
		
			
	}
}


species Stage skills: [fipa, moving] {
	
	// qualities
//	float lighting;
//	float sound;
//	float band;
//	float pyrotechnics;
//	float merch;
//	float alcohol;


	list<float> attributeList;
	rgb agentColor <- rgb("black");
	


	reflex newAct when: time mod rnd(20,150) = 0 {
		
		attributeList <- list_with(numberOfAttributes, rnd(0.9));
		agentColor <- rnd_color(200);
		do start_conversation (to: list(Guest), protocol: "fipa-propose", performative: "propose", contents: ["List of qualities: ", attributeList]);
	}
		
	aspect base {
	
		draw square(2) color: agentColor;
	}
}

species Guest skills: [fipa, moving] {
	
	// preferences
//	float lighting <- rnd(0.9);
//	float sound <- rnd(0.9);
//	float band <- rnd(0.9);
//	float pyrotechnics <- rnd(0.9);
//	float merch <- rnd(0.9);
//	float alcohol <- rnd(0.9);

	list<float> prefList <- list_with(numberOfAttributes, rnd(0.9));
	
	point targetPoint <- nil;
		
	list<Stage> stages;
	list<float> stageUtils;
	
	reflex gotoPos when: targetPoint != nil {
		do goto target:targetPoint;
	}
	
	reflex getProposal when: !empty(proposes) {
		message messageToRespond <- proposes[0];
		list content <- messageToRespond.contents;
		list<float> attributeList <- content[1];
		
		float util <- calcUtil(attributeList);
		Stage sender <- messageToRespond.sender;
		
		if length(stages) > 0 {
			loop counter from: 0 to: length(stages)-1 {
				if(sender = stages[counter]) {
					
					if(stages[counter].location = targetPoint) {
						write "Act closed, choosing new act";
					}
					remove index: counter from: stages;
					remove index: counter from: stageUtils;

					break;
				}
			}
		}

		
		add sender to: stages;
		add util to: stageUtils;
		
		int bestIndex <- 0;
		float bestUtil <- 0.0;
		
		loop counter from: 0 to: length(stages)-1 {
			if(stageUtils[counter] > bestUtil) {
				bestUtil <- stageUtils[counter];
				bestIndex <- counter;
			}
		}
		
		if stages[bestIndex] = sender {
			write "" + self + " Found new act with util: " + bestUtil;
			do accept_proposal(message:messageToRespond, contents:["omw"]);
		} else {
			do reject_proposal(message:messageToRespond, contents:["nothx"]);
		}
		
		targetPoint <- stages[bestIndex].location;
		
	}
	
	float calcUtil(list<float> attributeList) {
		float util <- 0.0;
		loop counter from:0 to: numberOfAttributes-1 {
			util <- util + (attributeList[counter]*prefList[counter]);
		}
		return util;
	}
	
	
	aspect base {
		rgb agentColor <- rgb("green");
		
		draw circle(1) color: agentColor;
	}
}

experiment my_experiment type:gui {
	output {
		display myDisplay {
			species Stage aspect:base;
			species Guest aspect:base;
		}
	}
}
