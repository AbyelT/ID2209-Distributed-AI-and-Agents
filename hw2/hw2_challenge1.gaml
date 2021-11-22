/**
* Name: hw2basic
* Based on the internal empty template. 
* Author: Flaxen
* Tags: 
*/


model hw2basic

global {
	
	
	int numberOfAuctioneers <- 2;
	int numberOfPatricipants <- 5;
	int distanceThreshold <- 2;
	
	int amountOfItems <- 2;
	list<int> itemMarketValue;
	
	init {
		
		loop counter from:0 to:amountOfItems-1 {
			add 2500 + rnd(1000) to: itemMarketValue; // all items vary between prices of 2500 and 3500
		}
		
			
		create Auctioneer number:numberOfAuctioneers;
		create Participant number:numberOfPatricipants;

		loop counter from: 0 to:numberOfAuctioneers-1 {
			Auctioneer[counter].name <- "Auctioneer " + counter;
			write Auctioneer[counter].name + " selling item: " + Auctioneer[counter].item;
			
		}
		loop counter from: 0 to:numberOfPatricipants-1 {
			Participant[counter].name <- "Participant " + counter;
			write Participant[counter].name + " interested in item: " + Participant[counter].interestedItem;
			
		}
		
		
	}
}

species Auctioneer skills: [fipa] {
	
	string name;
	
	int item <- rnd(amountOfItems-1);
	
	int price <- itemMarketValue[item] + rnd(500) + 1500; // 1500 to 2000 above market value as start value
	int minPrice <- int(itemMarketValue[item] * 0.75);
	int reductionPrice <- 150;
	int minParticipants <- 2;
	
	int setupTime <- 100;
	
	bool auctionClosed <- false;
	bool biddingStarted <- false;
	
	list bidders;
	list<message> messagesToRespond;
	
	aspect base {
		rgb agentColor <- rgb("red");
		
		draw circle(1) color: agentColor;
	}
	
	reflex start_auction when: (time = 1) {
		do start_conversation (to: list(Participant), protocol: "fipa-contract-net", performative: "inform", contents: ["selling item: ", item, "at price: ", price]);
		write name + ": broadcasting auction";
	}
	
	reflex add_to_auction when: !empty(agrees) {
		message temp <- agrees[0];
		add temp to: messagesToRespond;
		write name + ": adding " + temp.sender + " to bidders";
		add temp.sender to: bidders;
		do agree with: (message: temp, contents: ["ok"]);
		
	}
	
	reflex run_auction when: !empty(bidders) and !auctionClosed and time >= setupTime and !biddingStarted {
		biddingStarted <- true;
		do announce;
	}
		
	reflex continue_auction when: !empty(bidders) and length(proposes) = length(bidders) and !auctionClosed and time > setupTime {
		
		messagesToRespond <- [];
		
		loop p over: proposes {
			
			list contents <- p.contents;
			string offer <- contents[1];
			
			write name + ": offer from: " + p.sender + " at price: " + offer;
			//write proposes;
			add p to: messagesToRespond;
			
			if (offer as_int 10) >= price and !auctionClosed {
				do accept_proposal with: (message: p, contents: ["You got it!"]);
				write name + ": " + p.sender + "got the item";
				auctionClosed <- true;
			} else {
				
				write "rejected";
				do reject_proposal with: (message: p, contents: ["Too low"]);
			}
			
			
		}
		// no one had good price
		price <- price - reductionPrice;
		if(price < minPrice) {
			do terminateAuction;
		} else {
			do announce;
		}
	}
	
	reflex no_bidders when: empty(bidders) and time = setupTime + 9000 {
		auctionClosed <- true;
		write "no bidders after long time. closing auction";
	}
 	
	action terminateAuction {
				
		auctionClosed <- true;
		write name + ": Price fallen too low, terminating auction";
	}
	
	
	action announce {
		if(auctionClosed) {
			return;
		}
		
//		loop m over: messagesToRespond {
//			do cfp with: (message: m, contents: ["Sell for price: ", price]);
//			write "sending new cfp to " + m.sender;
//		}
		do start_conversation (to: bidders, protocol: "fipa-contract-net", performative: "cfp", contents: ["selling item: ", item, "at price: ", price]);
		//message p;
		//do cfp with: (message: p, contents: ["Sell for price: ", price]);
		write name + ": selling item: " + item + "for: " + price;		
	}
	
	

}

species Participant skills: [fipa] {
	
	string name;
	
	int interestedItem <- rnd(amountOfItems-1);
	
	
	bool inAuction <- false;
	int maxPrice <- itemMarketValue[interestedItem] - 500 + rnd(1000); // buyers offer price in range [marketValue-500, marketValue+500]
	
	Auctioneer ourAuction;
	
	reflex join_auction when: !inAuction and !empty(informs) {
		message informFromAuctioneer <- informs[0];
		list cont <- informFromAuctioneer.contents;
		string itemString <- cont[1];
		int itemAnnounced <- itemString as_int 10;
		
		if(itemAnnounced != interestedItem) {
			return;
		}
		
		
		inAuction <- true;
		ourAuction <- informFromAuctioneer.sender;
		
		//write name + " joining auctionneer " + ourAuction;
		do agree with: (message: informFromAuctioneer, contents: ["I am joining"]);
		
	}
	
	reflex partake_auction when: !empty(cfps) { // inAuction should no be needed here. check if strange behaviour
		message fromAuctioneer <- cfps[0];
		list cont <- fromAuctioneer.contents;
		string announcedPriceString <- cont[3];
		int announcedPrice <- announcedPriceString as_int 10;
		
		if(announcedPrice < maxPrice) {
			do propose with: (message: fromAuctioneer, contents: ["Buying for: ", announcedPrice]);
		} else {
			do propose with: (message: fromAuctioneer, contents: ["Buying for: ", maxPrice]);	
		}
	}
	
	
//	reflex check_auction when: inAuction {
//		ask ourAuction {
//			if self.auctionClosed {
//				myself.inAuction <- false;
//				write "seems auction is closed. leaving...";
//			}
//		}
//	}
	
	aspect base {
		rgb agentColor <- rgb("green");
		
		draw circle(1) color: agentColor;
	}
}

experiment my_experiment type:gui {
	output {
		display myDisplay {
			species Auctioneer aspect:base;
			species Participant aspect:base;
		}
	}
}
