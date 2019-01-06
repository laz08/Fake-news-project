progressBar <- function(current, upperBound){
    # Prints a progress bar
    
    currentStr = str_c(rep("#", current), collapse="")
    voidBound = upperBound - current
    voidStr = str_c(rep(".", voidBound), collapse="")
    print(paste(currentStr, voidStr, " [", current, "/", upperBound, "]", sep = ""))
}


createFakeNewsSubgraphFromId <- function(news.user.df, fakeNewsId, neighOrder=2, verbose=T) {
    # Given a fake news id, user-user network and a neighborhood order, a subgraph is created from the user-user network containing all those infected users + neighbors 2 jumps away.
    
    infected.rows <- news.user.df[news.user.df$FakeNewsId == fakeNewsId,]
    if(verbose){
        cat("Nr. infected rows for fakeNews ", fakeNewsId, ": ", nrow(infected.rows), "\n")    
    }
    
    fake.news.subgraphs.array <- make_ego_graph(users.graph, order=neighOrder, nodes=infected.rows$SharedBy)
    
    fake.news.subgraph = make_empty_graph(directed = F)
    for (x in length(fake.news.subgraphs.array)) {
        g = fake.news.subgraphs.array[[x]]    
        fake.news.subgraph = fake.news.subgraph + g
    }
    if(verbose){
        cat("Nr. users in network: ", length(V(fake.news.subgraph)), "\n")   
    }
    return(fake.news.subgraph)
}

selectNetworkWithLowerNrUsers <- function(news.user.df, lowerBound=1, upperBound=10) {
    # Given two bounds for fake news ids, this function returns the network with
    # the lowest number of users. Useful for testing purposes.
    info.table <- data.table(fakeNewsId = numeric(), nrVertices = numeric())
    for (x in lowerBound:upperBound) {
        progressBar(x, upperBound)
        fake.news.subgraph = createFakeNewsSubgraphFromId(news.user.df, x, verbose=F)
        info.table <- rbind(info.table, list(x, length(V(fake.news.subgraph))))    
    }
    cat("\n Fake news with lowest number of vertices: \n")
    minRow <- info.table[info.table$nrVertices == min(info.table$nrVertices), ]
    print(minRow)
    return(minRow$fakeNewsId)
}


simulateSIBaseline <- function(g, tmax, beta, verbose=F) {
    # Given a graph, a maximum time and a beta, performs an SI simulation.
    # It picks 3 random nodes as infected.
    # Beta is static.
    
    ts = 1:tmax
    
    edgelist <- as.data.frame(as_edgelist(g), stringsAsFactors = F)
    E = length(E(g))
    N = length(V(g))
    
    set.seed(321)
    nums = runif(tmax * E, 0, 1)
    
    # Start with infected nodes
    # TODO: Change method of choosing infected
    p = 3
    infected = rep(FALSE, N)
    infected.start = sample(N, p, prob=NULL)
    infected[infected.start] = TRUE
    
    # Data frame with vertices id, since they are identified already.
    vertices.infected = data.table(vId = as.numeric(V(g)$name), infected)
    
    # For each timestep...
    for (x in ts) {
        
        inf.prev.step <- vertices.infected[vertices.infected$infected == TRUE,]$vId
        
        # For each infected
        x.i <- 1 # subindex to get random prob.
        for (inf in inf.prev.step) {
            
            # we get the susceptibles related to the infected
            v.susceptible.1 = edgelist[edgelist$V1 == inf, ]$V2
            v.susceptible.2 = edgelist[edgelist$V2 == inf, ]$V1
            v.susc <- append(v.susceptible.1, v.susceptible.2)
            
            # Try to infect them if not infected
            for(vs in v.susc){
                alpha = nums[x * x.i]
                if(!vertices.infected[vertices.infected$vId == vs,]$infected & alpha <= beta){
                    vertices.infected[vertices.infected$vId == vs,]$infected = TRUE
                }
                x.i <- x.i + 1
            }
            
        }
        
        if(verbose){
            cat("It", x, ", nr. infected: ", nrow(vertices.infected[vertices.infected$infected == T,]), "/", N,"\n")   
        }
    }
    
}


selectSourceOfFakeNews <- function(fakeNewsId, g, n, news.user.df){
    # given a fakeNewsId, number of nodes to pick and dataset related to it
    # this function picks n vertices that could potentially be
    # the ones to first start spreading the fake news
    
    # Use centralization degree to pick 2/3 of the nodes + 1/3 as random pick
    centr = centralization.degree(g, mode = "all")
    degree.df <- data.table(vId = as.numeric(V(g)$name), degree=centr$res)
    degree.df <- degree.df[order(-degree.df$degree),] # Order descendingly by degree
    
    ## TODO: Try to take into account the number of times a user has shared some fake news?
    if(n > 2){
        n.top <- floor((n*2)/3)    
        toInfect <- degree.df[1:n.top, ]$vId # Most well connected vertices to infect
        n.rand <- n - n.top # Pick last rand nodes to reach n
        v.rand <- sample(degree.df$vId, n.rand, prob=NULL)
        toInfect <- append(toInfect, v.rand)
    } else {
        toInfect <- degree.df[1:n, ]$vId
    }
    return(toInfect)
}

plotEfficiencyPlot <- function(tmax=48){
    # Laura understanding of how effective are fake news on spreading as time progresses. 
    # Their peak is at the 2nd and 3rd hours.
    # They slowly decline as time progresses. After 48h, it just dies out.

    x.seq.max <- 10
    x <- seq(0, x.seq.max, by = .1)
    y <- dnorm(x, mean = 1.5, sd = 5)
    x <-x*tmax/x.seq.max # Scale x...
    y <- y/max(y)# Scale y....
    df = data.frame(x, y)
    ggplot(data = df) +
        aes(x = x, y = y) +
        geom_line(color = '#e31a1c') +
        labs(title = 'Beta evolution over time',
             x = 'time (hours)',
             y = 'Infection probability',
             subtitle = '(Efficiency of spread of fake news as time progresses)') +
        theme_minimal()
    
}

getEfficiencyOfFakeNews <- function(tmax=48){
    # Laura understanding of how effective are fake news on spreading as time progresses. 
    # Their peak is at the 2nd and 3rd hours.
    # They slowly decline as time progresses. After 48h, it just dies out.
    
    x.seq.max <- 10
    x <- seq(0, x.seq.max, by = 1)
    y <- dnorm(x, mean = 1.5, sd = 5)
    y <- y/max(y)
    return(y)
}