/**
* Name: hw3basicqueen
* Based on the internal empty template. 
* Author: Flaxen
* Tags: 
*/


model hw3basicqueen

/* Insert your model definition here */
global {
	
	int n <- 20;
	int numberOfQueens <- n;
	
	bool done <- false;
	
	list posTaken <- list_with(n, list_with(n, []));
	
	init {
		create Queen number:numberOfQueens;
		
		loop counter from: 0 to: n-1 {
			Queen[counter].id <- counter;
		}
				
		Queen[0].active <- true;
	}
	
	
	
}

grid myGrid width: n height: n {
	init {
			
	}
}

species Queen skills: [fipa, moving] {
	
	int id;
	bool active <- false;
	
	list posAvailable <- list_with(n, true);
	list<int> queenPositions;
	message messageToRespond;
		
	point targetPos <- nil;
	int x <- 0;
	int y <- id; // id 0 at init, set to id as we start
	
	point getFreeCell {
		//write "id testing: " + id;
		if(x = n) {
			do passUp;
			return nil;
		}
		loop while: !posAvailable[x] {
			
			//write "in while w " + x + " " + y + " taken: " + posTaken[x][y] + " been: " + beenBefore[x][y];
			x <- x+1;
			
			if(x = n) {
				do passUp;
				return nil;
			}
			
		} 
		//write "yep this good"+ " taken: " + posTaken[x][y] + " been: " + beenBefore[x][y];
		add x to: queenPositions;
		return myGrid[x,y].location;

	}
	
	
	action passUp {

		//write "sending pass up";
		targetPos <- nil;
		active <- false;
		x <- 0;
		y <- id;
		
		
		if(id = 0) {
			write "execution failed, could not find pos";
			return;
		}
		
		do reject_proposal(message: messageToRespond, contents: ["new pos plz"]);
		
	}
	

	
	reflex getPassUp when: !empty(reject_proposals) {
		message temp <- reject_proposals[0];
		
		list contents <- temp.contents;
		string s <- contents[0];
		
		//write "passup, len of rejects: " + length(reject_proposals);
		do unblockCells();
		targetPos <- nil;
		x <- x+1;
		y <- id;
		active <- true;
	}
	
	action blockCells {
		
		int temp;
		loop i from: 0 to: id-1 {
			posAvailable[queenPositions[i]] <- false;
			//write "blocking: " + queenPositions[i];
			
			temp <- queenPositions[i] + (id - i);
			if(temp > 0 and temp < n) {
				posAvailable[temp] <- false;
				//write "blocking: " + temp;
			}
			temp <- queenPositions[i] - (id - i);
			if(temp > 0 and temp < n) {
				posAvailable[temp] <- false;
				//write "blocking: " + temp;
				
			}
			
		}
	}
		
	action unblockCells {
		remove index: length(queenPositions)-1 from: queenPositions;
	}
	
	reflex getPassDown when: !empty(proposes) {
		//write "id: " + id + " got passdown, my x is " + x;
		
		messageToRespond <- proposes[0];
		posAvailable <- list_with(n, true);
		
		list contents <- messageToRespond.contents;
		queenPositions <- contents[1];
		y <- id; // se över att skicka extra värde med id eller sätta till id om vi litar på att det är satt
		do blockCells();
		active <- true;
				
		//write queenPositions;
	}
	
	reflex passDown when: targetPos != nil and active { // for movement location = target pos, for quicker targetPost != nil

		//write "pass down";
		//do blockCells(x, y);
		active <- false;
		
		if(id = n-1) {
			write "done";
			done <- true;
			return;
		}
		//write "from: " + id + " to: " + (id+1) + " sending: " + queenPositions;
		do start_conversation(to: [Queen[id+1]], protocol: "fipa-propose", performative: "propose", contents: ["List of x pos: ", queenPositions]);

		
	}
	

	reflex setPos when: targetPos = nil and active {
		targetPos <- getFreeCell();
	}
	
	reflex moveToPos when: targetPos != nil {
		do goto target:targetPos;
	}
	
	aspect base {
		rgb agentColor <- rgb("red");
		
		if(active) {
			agentColor <- rgb("green");
			
		}
		
		draw circle(1) color: agentColor;
	}
	
}


experiment my_experiment type:gui {
	output {
		display myDisplay {
			
			grid myGrid lines: #black;
			
			species Queen aspect:base;
		}
	}
}
