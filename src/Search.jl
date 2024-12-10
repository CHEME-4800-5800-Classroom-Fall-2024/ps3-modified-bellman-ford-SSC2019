
"""
    function _search(graph::T, start::MyGraphNodeModel, algorithm::DikjstraAlgorithm) where T <: MyAbstractGraphModel

This function performs a single source shortest path calculation on a graph model using the Dikjstra algorithm.

### Arguments
- `graph::T`: the graph model to search. This is a subtype of `MyAbstractGraphModel`.
- `start::MyGraphNodeModel`: the node to start the search from.
- `algorithm::DikjstraAlgorithm`: the algorithm to use for the search {DikjstraAlgorithm | BellmanFordAlgorithm}.

### Returns
- a tuple of two dictionaries: the first dictionary contains the distances from the starting node to all other nodes, and the second dictionary contains the previous node in the shortest path from the starting node to all other nodes.
"""
function _search(graph::T, start::MyGraphNodeModel, algorithm::DikjstraAlgorithm) where T <: MyAbstractGraphModel
    
    # initialize -
    distances = Dict{Int64, Float64}();
    previous = Dict{Int64, Union{Nothing,Int64}}();
    queue = PriorityQueue{Int64, Float64}(); # exported from DataStructures.jl

    # set distances and previous -
    distances[start.id] = 0.0; # distance from start to start is zero
    for (k, _) ∈ graph.nodes # what is this?
        if k != start.id
            distances[k] = Inf;
            previous[k] = nothing;
        end
        enqueue!(queue, k, distances[k]); # add nodes to the queue
    end

    # main loop -
    while !isempty(queue) # process nodes in the queue until it is empty (!isempty(queue) is the same as isempty(queue) == false)
        u = dequeue!(queue);
        mychildren = children(graph, graph.nodes[u]);

        for w ∈ mychildren # iterate over the children set of the current node
            alt = distances[u] + weight(graph, u, w); # distance to u so far + weight of edge from u to w
            if alt < distances[w] # Wow! the distance to w is less than the current best distance to w
                distances[w] = alt;
                previous[w] = u;
                queue[w] = alt;
            end
        end
    end

    # return -
    return distances, previous;
end

"""
    function _search(graph::T, start::MyGraphNodeModel, algorithm::BellmanFordAlgorithm) where T <: MyAbstractGraphModel

This function performs a single source shortest path calculation on a graph model using the Bellman Ford algorithm.

### Arguments
- `graph::T`: the graph model to search. This is a subtype of `MyAbstractGraphModel`.
- `start::MyGraphNodeModel`: the node to start the search from.
- `algorithm::BellmanFordAlgorithm`: the algorithm to use for the search {DikjstraAlgorithm | BellmanFordAlgorithm}.

### Returns
- a tuple of two dictionaries: the first dictionary contains the distances from the starting node to all other nodes, and the second dictionary contains the previous node in the shortest path from the starting node to all other nodes.
"""
function _search(graph::T, start::MyGraphNodeModel, algorithm::BellmanFordAlgorithm) where T <: MyAbstractGraphModel

    # initialize -
    distances = Dict{Int64, Float64}();
    previous = Dict{Int64, Union{Nothing,Int64}}();
    nodes = graph.nodes;
    number_of_nodes = length(nodes);

    # initialize distance and previous dictionaries -
    for (_, node) ∈ nodes
        distances[node.id] = Inf;
        previous[node.id] = nothing;
    end
    distances[start.id] = 0.0;

    # main loop -
    counter = 1;
    while counter < (number_of_nodes - 1)
        
        for (k, _) ∈ graph.edges

            u = k[1];
            v = k[2];

            alt = distances[u] + weight(graph, u, v);
            if alt < distances[v]
                distances[v] = alt;
                previous[v] = u;
            end
        end

        # increment counter -
        counter += 1;
    end

    # check: If we have negatice cycles, then we should throw an error. 
    for (k, _) ∈ graph.edges

        u = k[1];
        v = k[2];

        if distances[u] + weight(graph, u, v) < distances[v]
            throw(ArgumentError("The graph contains a negative cycle"));
        end
    end

    # check fo
    return distances, previous;
end

"""
    function _search(graph::T, start::MyGraphNodeModel, algorithm::ModifiedBellmanFordAlgorithm) where T <: MyAbstractGraphModel

This function performs a single source shortest path calculation on a graph model using the Modified Bellman Ford algorithm.
This version of Bellman-Ford should respect node capacities

### Arguments
- `graph::T`: the graph model to search. This is a subtype of `MyAbstractGraphModel`.
- `start::MyGraphNodeModel`: the node to start the search from.
- `algorithm::ModifiedBellmanFordAlgorithm`: the algorithm to use for the search {DikjstraAlgorithm | BellmanFordAlgorithm | ModifiedBellmanFordAlgorithm}.

### Returns
- a tuple of two dictionaries: the first dictionary contains the distances from the starting node to all other nodes, and the second dictionary contains the previous node in the shortest path from the starting node to all other nodes.
"""
function _search(graph::T, start::MyGraphNodeModel, algorithm::ModifiedBellmanFordAlgorithm) where T <: MyAbstractGraphModel
    
    # initialize -
    distances = Dict{Int64, Float64}();
    previous = Dict{Int64, Union{Nothing,Int64}}();
    nodes = graph.nodes;
    number_of_nodes = length(nodes);
    
    # initialize distance and previous dictionaries correctly -
    for (_, node) ∈ nodes
        distances[node.id] = Inf;
        previous[node.id] = nothing;
    end
    distances[start.id] = 0.0;  # Set start distance after initialization

    # initialize node assignment counters
    node_assignments = Dict{Int64, Tuple{Int64, Int64}}()
    for (id, _) in nodes
        node_assignments[id] = (0, 0)  # (in_degree_usage, out_degree_usage)
    end

    # main loop -
    for _ in 1:(number_of_nodes - 1)
        updated = false
        
        for (k, _) ∈ graph.edges
            u = k[1]
            v = k[2]
            
            if distances[u] != Inf
                alt = distances[u] + weight(graph, u, v);
                
                # Get node capacities safely
                u_node = graph.nodes[u]
                v_node = graph.nodes[v]
                u_capacity = u_node.capacity
                v_capacity = v_node.capacity
                
                # Get current assignments
                u_out_degree = node_assignments[u][2]
                v_in_degree = node_assignments[v][1]
                
                # Check if the path is shorter and respects capacity constraints
                if alt < distances[v] && 
                   (u_capacity === nothing || u_out_degree < u_capacity[2]) &&
                   (v_capacity === nothing || v_in_degree < v_capacity[1])
                    
                    # Remove old assignments if they exist
                    if previous[v] !== nothing
                        prev_u = previous[v]
                        # Update old source node's out-degree
                        old_out = node_assignments[prev_u][2] - 1
                        old_in = node_assignments[prev_u][1]
                        node_assignments[prev_u] = (old_in, old_out)
                        
                        # Update target node's in-degree
                        old_in = node_assignments[v][1] - 1
                        old_out = node_assignments[v][2]
                        node_assignments[v] = (old_in, old_out)
                    end
                    
                    # Update distance and previous
                    distances[v] = alt
                    previous[v] = u
                    
                    # Update new assignments
                    new_in = node_assignments[u][1]
                    new_out = node_assignments[u][2] + 1
                    node_assignments[u] = (new_in, new_out)
                    
                    new_in = node_assignments[v][1] + 1
                    new_out = node_assignments[v][2]
                    node_assignments[v] = (new_in, new_out)
                    
                    updated = true
                end
            end
        end

        # Early termination for positive-weight graphs
        if !updated
            break
        end
    end

    # Check for negative cycles while respecting capacity constraints
    for (k, _) ∈ graph.edges
        u = k[1]
        v = k[2]
        if distances[u] != Inf && 
           distances[u] + weight(graph, u, v) < distances[v]
            throw(ArgumentError("The graph contains a negative cycle"))
        end
    end

    return distances, previous
end


# ------ PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #
"""
    computeshortestpaths(graph::T, start::MyGraphNodeModel, 
        algorithm::MyAbstractGraphSearchAlgorithm) where T <: MyAbstractGraphModel

The function computes the shortest paths from a starting node to all other nodes in a graph model. 

### Arguments
- `graph::T`: the graph model to search. This is a subtype of `MyAbstractGraphModel`.
- `start::MyGraphNodeModel`: the node to start the search from.
- `algorithm::MyAbstractGraphSearchAlgorithm`: the algorithm to use for the search.

### Returns
- a tuple of two dictionaries: the first dictionary contains the distances from the starting node to all other nodes, and the second dictionary contains the previous node in the shortest path from the starting node to all other nodes.
"""
function computeshortestpaths(graph::T, start::MyGraphNodeModel, 
    algorithm::MyAbstractGraphSearchAlgorithm) where T <: MyAbstractGraphModel
    return _search(graph, start, algorithm);
end
# ------ PUBLIC ABOVE BELOW HERE ---------------------------------------------------------------------------------- #