/**
* Name: hw2basic
* Based on the internal empty template. 
* Author: Flaxen
* Tags: 
*/


model hw2basic

global {
	
	int item1MarketValue <- 3000;
	
	int numberOfAuctioneers <- 1;
	int numberOfPatricipants <- 5;
	int distanceThreshold <- 2;
	
	init {
		create Auctioneer number:numberOfAuctioneers;
		create Participant number:numberOfPatricipants;		
			
	}
}

species Auctioneer skills: [fipa] {
	
	int price <- item1MarketValue + rnd(500) + 1500; // 1500 to 2000 above market value as start value
	int minPrice <- int(item1MarketValue * 0.75);
	int reductionPrice <- 150;
	int minParticipants <- 2;
	
	bool auctionClosed <- false;
	
	list bidders;
	list<message> messagesToRespond;
	
	aspect base {
		rgb agentColor <- rgb("red");
		
		draw circle(1) color: agentColor;
	}
	
	reflex start_auction when: (time = 1) {
		write "broadcasting auction";
		do start_conversation (to: list(Participant), protocol: "fipa-contract-net", performative: "inform", contents: ["selling item 1 at price: ", price]);
		write "informing of auction!";
	}
	
	reflex add_to_auction when: !empty(agrees) {
		message temp <- agrees[0];
		add temp to: messagesToRespond;
		write "adding " + temp.sender + " to bidders";
		add temp.sender to: bidders;
		do agree with: (message: temp, contents: ["ok"]);
		
	}
	
	reflex run_auction when: length(bidders) = numberOfPatricipants and !auctionClosed and empty(proposes) {
		do announce;
	}
	
	
	reflex continue_auction when: length(proposes) = numberOfPatricipants and !auctionClosed {
		
		messagesToRespond <- [];
		
		loop p over: proposes {
			
			list contents <- p.contents;
			string offer <- contents[1];
			
			write "offer from: " + p.sender + " at price: " + offer;
			//write proposes;
			add p to: messagesToRespond;
			
			if (offer as_int 10) >= price and !auctionClosed {
				do accept_proposal with: (message: p, contents: ["You got it!"]);
				write "" + p.sender + "got the item";
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
	
	action terminateAuction {
				
		auctionClosed <- true;
		write "Price fallen too low, terminating auction";
	}
	
	action announce {
		if(auctionClosed) {
			return;
		}
		
//		loop m over: messagesToRespond {
//			do cfp with: (message: m, contents: ["Sell for price: ", price]);
//			write "sending new cfp to " + m.sender;
//		}
		do start_conversation (to: bidders, protocol: "fipa-contract-net", performative: "cfp", contents: ["Sell for price: ", price]);
		//message p;
		//do cfp with: (message: p, contents: ["Sell for price: ", price]);
		write "selling for " + price;		
	}
	
	

}

species Participant skills: [fipa] {
	
	bool inAuction <- false;
	int maxPrice <- item1MarketValue - 500 + rnd(1000); // buyers offer price in range [marketValue-500, marketValue+500]
	
	Auctioneer ourAuction;
	
	reflex join_auction when: !inAuction and !empty(informs) {
		inAuction <- true;
		
		message informFromAuctioneer <- informs[0];
		
		ourAuction <- informFromAuctioneer.sender;
		
		write informFromAuctioneer;
		do agree with: (message: informFromAuctioneer, contents: ["I am joining"]);
		
	}
	
	reflex partake_auction when: !empty(cfps) { // inAuction should no be needed here. check if strange behaviour
		//list splitt <- (cfps[0].contents split_using ": ");
		message fromAuctioneer <- cfps[0];
		list cont <- fromAuctioneer.contents;
		string announcedPriceString <- cont[1];
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
	

	//reflex reply when (!empty())
	
	
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
