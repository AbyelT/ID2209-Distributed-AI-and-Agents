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
	
	int amountOfAuctionTypes <- 3; // 0 = dutch, 1 = sealed bid, 2 = 日本の
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
			write Participant[counter].name + " interested in item: " + Participant[counter].interestedItem + " for price:" + Participant[counter].maxPrice;
			
		}
		
		
	}
}

species Auctioneer skills: [fipa] {
	
	string name;
	
	int auctionType <- rnd(2);
	int item <- rnd(amountOfItems-1);
	
	int price;
	int minPrice <- int(itemMarketValue[item] * 0.75);
	int reductionPrice <- 150;
	int minParticipants <- 2;
	
	int setupTime <- 100;
	
	bool auctionClosed <- false;
	bool biddingStarted <- false;
	
	list bidders;
	list<message> messagesToRespond;
	
	init {
		if(auctionType = 0) {
			price <- itemMarketValue[item] + rnd(500) + 1500; // 1500 to 2000 above market value as start value for dutch auction
		} else if (auctionType = 2) {
			// japanese
			price <- int(itemMarketValue[item] * 0.1); // start at 10% for japanese
		}
		
		write name + " using auctiontype:" + auctionType;
	}
	
	aspect base {
		rgb agentColor <- rgb("red");
		
		draw circle(1) color: agentColor;
	}
	
	reflex start_auction when: (time = 1) and auctionType != 1 {
		do start_conversation (to: list(Participant), protocol: "fipa-contract-net", performative: "inform", contents: ["selling item: ", item, " using auctionType: ", auctionType, "at price: ", price]);
		write name + ": broadcasting dj auction";
	}
	
	reflex start_auction2 when: time = 1 and auctionType = 1 {
		do start_conversation (to: list(Participant), protocol: "fipa-contract-net", performative: "inform", contents: ["selling item: ", item, " using auctionType: ", auctionType]);
		write name + ": broadcasting closed auction";
	}
	
	reflex add_to_auction when: !empty(agrees) {
		message temp <- agrees[0];
		write name + ": adding " + temp.sender + " to bidders";
		add temp.sender to: bidders;
		do agree with: (message: temp, contents: ["ok"]);
		
	}
	
	reflex run_dj_auction when: !empty(bidders) and !auctionClosed and time >= setupTime and !biddingStarted and auctionType != 1 {
		biddingStarted <- true;
		do announce;
	}
	
	reflex run_closed_auction when: !empty(bidders) and !auctionClosed and time >= setupTime and !biddingStarted and auctionType = 1 {
		biddingStarted <- true;
		
		do start_conversation (to: bidders, protocol: "fipa-contract-net", performative: "cfp", contents: ["selling item: ", item, " using auction type: ", auctionType]);
	}
	
	reflex continue_closed_auction when: !empty(bidders) and length(proposes) = length(bidders) and biddingStarted and auctionType = 1 and !auctionClosed {
		message biggestMessage;
		int biggestPrice <- 0;
		list<message> toReject;
		
		loop p over: proposes {
			list cont <- p.contents;
			string offerString <- cont[1];
			int priceOffer <- offerString as_int 10;
			
			write name + ": got offer: " + priceOffer + " from: " + p.sender;
			if(priceOffer > biggestPrice) {
				add biggestMessage to: toReject;
				
				biggestPrice <- priceOffer;
				biggestMessage <- p;
			} else {
				add p to: toReject;
			}
		}
		
		write name + ": " + biggestMessage.sender + " got it!";
		do accept_proposal with: (message: biggestMessage, contents: ["you got it!"]);
		
		remove index:0 from: toReject;
		loop r over: toReject {
			do reject_proposal with: (message: r, contents: ["no"]);
		}
		
		auctionClosed <- true;
		
	}
	
	reflex continue_japanese_auction when: !empty(bidders) and length(proposes) = length(bidders) and biddingStarted and auctionType = 2 and !auctionClosed {
		
		loop p over: proposes {
			list cont <- p.contents;
			write name + ": someone said:" + cont[0];
			if(length(bidders) = 1) {
				write name + ": " + p.sender + " got it!";
				do accept_proposal with: (message: p, contents: ["You got it!"]);
				auctionClosed <- true;
				return;
			}
			
			if(cont[0] = "refusing") {
				remove p.sender from: bidders;
				do reject_proposal with: (message: p, contents: ["no"]);
			}
			
		}
		
		price <- price + reductionPrice;
		do announce;
	}
	
	reflex continue_dutch_auction when: !empty(bidders) and length(proposes) = length(bidders) and !auctionClosed and time > setupTime and auctionType = 0 {
		
		
		loop p over: proposes {
			
			list contents <- p.contents;
			string offer <- contents[1];
			
			write name + ": offer from: " + p.sender + " at price: " + offer;
			//write proposes;
			
			if (offer as_int 10) >= price and !auctionClosed {
				do accept_proposal with: (message: p, contents: ["You got it!"]);
				write name + ": " + p.sender + "got the item";
				auctionClosed <- true;
			} else {
				
				write name + ": rejected";
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
		write name + ": no bidders after long time. closing auction";
	}
 	
	action terminateAuction {
				
		auctionClosed <- true;
		write name + ": Price fallen too low, terminating auction";
	}
	
	action announce {
		if(auctionClosed) {
			return;
		}
		
		do start_conversation (to: bidders, protocol: "fipa-contract-net", performative: "cfp", contents: ["selling item: ", item, " using auction type: ", auctionType, "at price: ", price]);
		write name + ": selling item: " + item + " for: " + price;		
	}
	
	

}

species Participant skills: [fipa] {
	
	string name;
	
	int auctionType;
	int interestedItem <- rnd(amountOfItems-1);
	
	
	bool inAuction <- false;
	int maxPrice <- itemMarketValue[interestedItem] - 500 + rnd(1000); // buyers offer price in range [marketValue-500, marketValue+500]
	int closedBid <- itemMarketValue[interestedItem] - 250 + rnd(249); // strategy for closed is just under true value
	
	Auctioneer ourAuction;
	
	reflex join_auction when: !inAuction and !empty(informs) {
		message informFromAuctioneer <- informs[0];
		list cont <- informFromAuctioneer.contents;
		string itemString <- cont[1];
		string typeString <- cont[3];
		int itemAnnounced <- itemString as_int 10;
		
		if(itemAnnounced != interestedItem) {
			return;
		}
		
		auctionType <- typeString as_int 10;
		inAuction <- true;
		ourAuction <- informFromAuctioneer.sender;
		
		//write name + " joining auctionneer " + ourAuction;
		do agree with: (message: informFromAuctioneer, contents: ["I am joining"]);
		
	}
	
	reflex partake_japanese_auction when: !empty(cfps) and auctionType = 2 {
		message fromAuctioneer <- cfps[0];
		list cont <- fromAuctioneer.contents;
		string announcedPriceString <- cont[5];
		int announcedPrice <- announcedPriceString as_int 10;
		
		if(announcedPrice > maxPrice) {
			do propose with: (message: fromAuctioneer, contents: ["refusing"]);
		} else {
			do propose with: (message: fromAuctioneer, contents: ["im in"]);
		}
	}
	
	reflex partake_closed_auction when: !empty(cfps) and auctionType = 1 {
		do propose with: (message: cfps[0], contents: ["Buying for: ", closedBid]);
	}
	
	reflex partake_dutch_auction when: !empty(cfps) and auctionType = 0 { // inAuction should no be needed here. check if strange behaviour
		message fromAuctioneer <- cfps[0];
		list cont <- fromAuctioneer.contents;
		string announcedPriceString <- cont[5];
		int announcedPrice <- announcedPriceString as_int 10;
		
		if(announcedPrice < maxPrice) {
			do propose with: (message: fromAuctioneer, contents: ["Buying for: ", announcedPrice]);
		} else {
			do propose with: (message: fromAuctioneer, contents: ["Buying for: ", maxPrice]);	
		}
	}
	
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
