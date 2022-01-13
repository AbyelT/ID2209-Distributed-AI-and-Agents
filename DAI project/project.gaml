/**
* Name: project_ver1
* Based on the internal empty template. 
* Author: Flaxen
* Tags: 
*/


model project_ver1

global {
	// global variable to track
	int universalHappiness <- 0;
	
	// editable variables to change simulation
	int numberOfBars <- 4;
	int numberOfCampsites <- 4;
	int numberOfGuests <- 50;
	float campsiteBonus <- 0.15; // the bonus utility gained from being at a campsite 0.15
	float hatedUtilModificationValue <- -0.1; // affects utility if a guest belonging to a "hated" team is found -0.1
	float badInteractionThreshold <- 0.55; // draws line where bad interactions are. sets upper range of util ex: [0, badInteractionThreshold] gives a bad interaction 0.38
	int numberOfTeamAffiliates <- 10; // OBS: has to be numberOfGuests/length(teams)
	
	// other variables used during simulations
	int distanceThreshold <- 2;
	int numberOfPlaces <- numberOfBars + numberOfCampsites;
	list<string> teams <- ["AIK", "DIF", "HIF", "MFF", "IFKG"];
	int numberOfTeams <- length(teams);
	list ruleList <- list_with(numberOfTeams, list_with(numberOfTeams, 0.0));
	int numberOfAttributes <- 6;
	
	// used for pausing the simulation during certain events. set the pause_flag to true when you wish to automatically pause the simulation
	// used for debugging and demonstration purposes
	bool pause_flag <- false;
	reflex pause_sim when: pause_flag {
		pause_flag <- false;
		do pause;
	}
			
	
	init {
		create Place number:numberOfPlaces;
		create Guest number:numberOfGuests;	
		
		// assign bars to places
		loop counter from: 0 to: numberOfBars - 1 {
			Place[counter].type <- "bar";
			Place[counter].defaultColor <- #brown;
			Place[counter].agentColor <- #brown;
		}
		
		// assign campsites to places
		loop counter from: numberOfBars to: numberOfPlaces - 1 {
			Place[counter].type <- "campsite";
			Place[counter].defaultColor <- #purple;
			Place[counter].agentColor <- #purple;
			
		}
		
		// loop for evenly distributing teams
		loop counter from: 0 to: length(teams)-1 {
			loop counter2 from: 0 to: numberOfTeamAffiliates-1 {
				Guest[counter2 + counter*10].team <- teams[counter];
			}

		}
		
		loop g over: Guest {
			write "" + g + " team:" + g.team;
		}
		
		// set up relation list
		// relations are negative diagonally shifted by 1 to the right
		ruleList[0][length(ruleList)-1] <- hatedUtilModificationValue; 
		int j <- 0;
		loop i from:1 to:length(ruleList)-1 {	
			ruleList[i][j] <- -0.1;
			j <- j+1;	
		}
	}
	
	// variables for better graph tracking
	int unimax <- 10;
	int unimin <- -10;
	
	// reflex for updating minmax variables
	reflex updateMinMax {
		if (universalHappiness > unimax) {
			unimax <- universalHappiness;
		}
		
		if(universalHappiness < unimin) {
			unimin <- universalHappiness;
		}
	} 
	
}

// the guests visit different places and interact with each other when places are visited
// can be affiliated to 5 different football teams
// different teams affect interactions
species Guest skills: [moving, fipa] {
	
	// get random team from team list
	//string team <- teams[rnd(length(teams)-1)];
	string team;
	
	// 3 personal traits
	float knowledge <- rnd(1.0);
	float personality <- rnd(1.0);
	float alcoholTolerence <- rnd(1.0);

	// 3 personal preferences on traits
	float knowledgePref <- rnd(1.0);
	float personalityPref <- rnd(1.0);
	float alcoholTolerencePref <- rnd(1.0); 
	
	// movement variables
	point targetPoint <- nil;
	Place targetPlace <- nil;
	
	// variables for guest interaction
	Guest toTalkTo <- nil;
	list<Guest> alreadySpokenTo;
	float util <- 0.0;
	list<Guest> HIF_friends;
	
	float startedFight <- 0.0; // timestamp of when a fight started
	
	// flags
	bool inPlace <- false;
	bool notAskedForUtilYet <- true;
	bool targetIsSpecial <- false;
	bool busy <- false;
	bool doingMegabad <- false;
	bool omw <- false;
	
	rgb agentColor <- #green;
	
	aspect base {
		
		// resets guest color coding when constraints are reached
		if(agentColor = #orange and location = targetPlace.location) {
			agentColor <- #green;
			omw <- false;
			
		} else if(agentColor = #blue and targetPoint != nil) {
			agentColor <- #green;
		} else if(agentColor = #cyan and !inPlace) {
			agentColor <- #green;
		} else if(agentColor = #orange and !omw) {
			agentColor <- #green;
		}
		
		
		draw circle(1) color: agentColor;
	}
	
	// help function for converting affiliate team name to index value of said team in the team list
	// used for navigating and extracting values from the rule list indicating hated team relations
	int nameToInt(string nameIn) {
		
		loop counter from: 0 to: length(teams)-1 {
			if(teams[counter] = nameIn) {
				return counter;
			}
		}
		
		write name + ": " +"name not found";
		return -1;
	}
	
	// idle function when nowhere to go
	reflex idle when: targetPoint = nil {
		if(agentColor != #blue and agentColor != #orange) {
			agentColor <- #green;
		}
		do wander;
	}
	
	// gets a place to go to in order to start interactions
	reflex targetPlace when: targetPoint = nil and flip(0.3) and time mod 20 = 0 and !inPlace and !omw {
		
		targetPlace <- Place[rnd(length(Place)-1)];
		targetPoint <- targetPlace.location;	
	}
	
	// reflex for going to targetPoint
	reflex gotoTarget when: targetPoint != nil {
		do goto target:targetPoint;
	}
	
	// reflex triggered as guest enters a place. adds itself to place guestlist
	reflex enterPlace when: Place at_distance distanceThreshold contains targetPlace and !inPlace {
		ask targetPlace {
			do addToGuestList(myself);
		}
		inPlace <- true;
	}
	
	// gets a guest to talk to
	// makes sure the guest to talk to is free
	// locks both guests in a conversation
	reflex getGuestToTalkTo when: toTalkTo = nil and inPlace and flip(0.05) {
		Guest temp;
		ask targetPlace {
			temp <- self.guestList[rnd(length(guestList)-1)];
			if temp != myself and temp.toTalkTo = nil and !(myself.alreadySpokenTo contains temp) {
				add temp to: myself.alreadySpokenTo;
				add myself to: temp.alreadySpokenTo;
				myself.toTalkTo <- temp;
				temp.toTalkTo <- myself;
			}
		}
	}
	
	// gets attributes from the conversation partner if it has not already been received
	// calculates utility based on attributes, team affiliation and place
	reflex talkToGuest when: toTalkTo != nil and notAskedForUtilYet {
		notAskedForUtilYet <- false;
		
		ask toTalkTo {
			util <- self.knowledge*myself.knowledgePref + self.personality*myself.personalityPref + self.alcoholTolerence*myself.alcoholTolerencePref 
				+ ruleList[nameToInt(myself.team)][nameToInt(self.team)];
				
			if(targetPlace.type = "campsite") {
				util <- util + campsiteBonus;
			}
			
			if(ruleList[nameToInt(myself.team)][nameToInt(self.team)] != 0) {
				myself.targetIsSpecial <- true;
			}
			
		}
		do actOnUtil;
	}
	
	// makes a guest interact based on the calculated utility
	action actOnUtil {
		switch util {
			
			// range for bad interaction
			match_between[-999.0, badInteractionThreshold] {
				
				// bad interaction with someone from "hated" team induces "mega bad" behaviour, affecting the unique rule set of each guest type
				if(targetIsSpecial) {
					do megaBad;
				} else {
					do bad;
				}
			}
			
			// range for good interaction
			match_between[badInteractionThreshold, 999.0] {
				do good;			
			}
		}
	}
	
	// good interaction increases happiness. guests stay together until one leaves the bar
	// guests affiliated with team HIF add each other to their friends list
	action good {
		if(team = "HIF" and toTalkTo.team = "HIF" and !(HIF_friends contains toTalkTo)) {
			add toTalkTo to: HIF_friends;
		}
		universalHappiness <- universalHappiness + 1;
	}
	
	// a bad interaction causes the offended guest to decrease the happiness
	// guest stop their conversation in order to search for a new conversation partner
	action bad {
		if(!toTalkTo.busy) {
			write "" + self + " bad, leaving " + toTalkTo;
			do stopConversation;
			universalHappiness <- universalHappiness - 1;
		}		
	}
	
	// starts unique bad interaction depending on team affiliation
	action megaBad {
		
		switch team {
			
			// affiliates of AIK start fights in the place
			// a fight in a place will affect everyone in the place negatively
			// all other guests in the place will leave the place in fear
			match("AIK") {
				write "" + self + ": FIGHT with " + toTalkTo;
				startedFight <- time;
		
				busy <- true;
				ask toTalkTo {
					busy <- true;
				}
				
				ask targetPlace {
					hasFight <- true;
				}
			}
			
			// affiliates of DIF leaves the place directly
			// only directly affects their happiness 
			match("DIF") {
				if(!busy) {
					write "" + self + ": EW leaving Place from " + toTalkTo;
					universalHappiness <- universalHappiness - 1;
					//do stopConversation;
					do leavePlace;
					agentColor <- #blue;
				}
			}
			
			// affiliates of HIF calls all their friends to join them in the place
			// if no friends are found affects happiness negatively
			match("HIF") {
				write "" + self + " calling friends";
				if(!empty(HIF_friends)) {
					do start_conversation (to: HIF_friends, protocol: "fipa-request", performative: "request", contents: ["Need help at: ", targetPlace]);
				} else {
					universalHappiness <- universalHappiness - 1;
				}
				
			}
			
			// affiliates of MFF start fights outside of the place
			// will only affect the two fighters
			match("MFF") {
				write "" + self + ": lets take this outside with " + toTalkTo;
				startedFight <- time;
		
				busy <- true;
				ask toTalkTo {
					busy <- true;
				}
				
				agentColor <- #cyan;
				targetPoint <- location + 3;
				
				ask toTalkTo {
					agentColor <- #cyan;
					targetPoint <- location + 2;
				}
				universalHappiness <- universalHappiness - 2;
				
			}
			
			// affiliates of IFKG makes fun of all members of the "hated" team in the place
			// affects happiness of all affiliates of the "hated" team, present in the bar, negatively
			match("IFKG") {
				//pause_flag <- true;
				write "" + self + "HAH you team is bad";
				ask targetPlace {
					loop g over: guestList {
						if(g.team = myself.toTalkTo.team) {
							universalHappiness <- universalHappiness - 1;
						}
					}
				}
			}
		}
	}
	
	// ends an active fight after 100 cycles
	// resets values of active guest and toTalkTo in order to proceed with future interactions
	reflex endFight when: startedFight != 0.0 and time >= startedFight+100 and busy {
		startedFight <- 0.0;
		busy <- false;
		
		
		ask toTalkTo {
			busy <- false;
			do leavePlace;
		}
		
		if(team = "AIK") {
			ask targetPlace {
				hasFight <- false;
			}
		}

		
		do stopConversation;
		do leavePlace;
	}
	
	// makes agent flee the visiting place when a fight occurs
	// affects happiness negatively
	reflex fleeFight when: targetPlace != nil and targetPlace.hasFight and !busy {
		universalHappiness <- universalHappiness - 1;
		do leavePlace;
	}
	
	// reflex for leaving the currently visited place	
	reflex leavePlace when: inPlace and time mod rnd(100,200) = 0 and !busy {
		do leavePlace;
	}
	
	// makes a guest leave the currently visited place
	// ends the current conversation and leaves the bar
	// resets variables for idling and future interactions
	action leavePlace {
		ask targetPlace {
			remove myself from: guestList;
		}
		alreadySpokenTo <- [];
		targetPlace <- nil;
		targetPoint <- nil;
		do stopConversation;
		inPlace <- false;
	}
	
	// stops the conversation between the active guest and toTalkTo
	// resets variables for both parts in order to allow future interactions
	action stopConversation {
		if(toTalkTo != nil){
			ask toTalkTo{
				self.toTalkTo <- nil;	
				self.notAskedForUtilYet <- true;
			}
		}

		toTalkTo <- nil;
		notAskedForUtilYet <- true;
	}
	
	// accepts a call to join a friend in a place
	// leaves any current place and conversation and moves to the place of the calling friend
	reflex accept_call when: !empty(requests) and !busy {
		message toRespond <- requests[0];
		list content <- toRespond.contents;
		Place b <- content[1];
		
		do agree(message: toRespond, contents: ["ok omw"]);
		
		if(inPlace) {
			do leavePlace;
		}
		targetPlace <- b;
		targetPoint <- targetPlace.location;
		agentColor <- #orange;
		omw <- true;
	}
}

// the places available for guests to visit
// can be bars or campsites
// type of place affects guest interactions
species Place {
	string type; // string for showing place type. bar/campsite
	
	rgb defaultColor; // default color used when no activities take place. different depending on type
	rgb agentColor; // active color, can be default or some color to signal some kind of event
	
	float startedFight <- 0.0;
	bool noTimer <- true;
	bool hasFight <- false;	// flag for indicating if there is a fight in the place. used for changing color and for making guests flee the place
	list<Guest> guestList <- []; // list keeping track of what guests are present in the place
	
	aspect base {
		
		// color is set depending on current events
		if(hasFight) {
			agentColor <- #red;
		} else {
			agentColor <- defaultColor;
		} 
		
		// shape is drawn depending on type
		if(type = "bar") {
			draw square(2) color: agentColor;
		} else if(type = "campsite"){
			draw triangle(3) color: agentColor;
			
		}
	}
	
	// adds guest to guest list
	action addToGuestList(Guest toAdd) {
		add toAdd to: guestList;
	}
	
	reflex setFightTimer when: hasFight and noTimer {
		noTimer <- false;
		startedFight <- time;
		
	}
	
	reflex stopFight when: hasFight and startedFight != 0.0 and time > startedFight+100 {
		startedFight <- 0.0;		
		hasFight <- false;
		noTimer <- true;
	}
	
}

// simulation legend
// circles: guests
// 		green: not interacting
//		orange: on way to friend in place
//      blue: left place due to bad interaction
//		cyan: fighting outside of the palce
//
// squares: bars
// 		green: nothing special happening
//		red: fight occuring in place
// triangles: campsites
// 		purple: nothing special happening
//		red: fight occuring in place

// sets up the experiment
experiment my_experiment type:gui {
	output {
		
		// the display showing places and guests and their interactions
		display myDisplay {
			species Guest aspect:base;
			species Place aspect:base;
			
		}
		
		// the display for tracking the universal happiness
		display infoDisplay {
			chart "universal happy" type: series x_range:[0, time+10] y_range:[unimin, unimax] {
				data "data" value: universalHappiness color: #black;
			}
		}
	}
}
