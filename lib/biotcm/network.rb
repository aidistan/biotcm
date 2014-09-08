require 'biotcm/table'

module BioTCM
  # One of the basic data models used in BioTCM to process network/graph
  # files, developed under <b>"strict entry and tolerant exit"</b> philosophy.
  #
  # Please refer to the test for details. 
  class BioTCM::Network
    # Valide interaction types
    INTERACTION_TYPES = ['--', '->']
    # List of nodes
    attr_reader :node
    def node; @node.keys; end
    # List of edges
    attr_reader :edge
    def edge; @edge.keys; end
    # Table of all nodes
    attr_reader :node_table
    # Table of all edges
    attr_reader :edge_table
    # Create a network from file(s)
    # @param edge_file [String] file path
    # @param node_file [String ]file path
    def initialize(edge_file = nil, node_file = nil,
        column_source_node:"_source", 
        column_interaction_type:"_interaction", 
        column_target_node:"_target"
    )
      fin = File.open(edge_file)
      
      # Headline
      col = fin.gets.chomp.split("\t")
      i_src = col.index(column_source_node) or raise ArgumentError, "Cannot find source node column: #{column_source_node}"
      i_typ = col.index(column_interaction_type) or raise ArgumentError, "Cannot find interaction type column: #{column_interaction_type}"
      i_tgt = col.index(column_target_node) or raise ArgumentError, "Cannot find target node column: #{column_target_node}"
      col[i_src] = nil; col[i_typ] = nil; col[i_tgt] = nil; col.compact!
      
      # Initialize members
      @node_table = BioTCM::Table.new
      @node_table.primary_key = "Node"
      @edge_table = BioTCM::Table.new
      @edge_table.primary_key = "Edge"
      col.each { |c| @edge_table.col(c, {}) }

      # Load edge_file
      node_in_table = @node_table.instance_variable_get(:@row_keys)
      col_size = @edge_table.col_keys.size
      fin.each_with_index do |line, line_no|
        col = line.chomp.split("\t")
        raise ArgumentError, "Unrecognized interaction type: #{col[i_typ]}" unless INTERACTION_TYPES.include?(col[i_typ])
        src = col[i_src]; typ = col[i_typ]; tgt = col[i_tgt];
        # Insert nodes
        @node_table.row(src, []) unless node_in_table[src]
        @node_table.row(tgt, []) unless node_in_table[tgt]
        # Insert edge
        col[i_src] = nil; col[i_typ] = nil; col[i_tgt] = nil; col.compact!
        raise ArgumentError, "Row size inconsistent in line #{line_no+2}" unless col.size == col_size
        @edge_table.row(src+typ+tgt, col)
      end

      # Load node_file
      if node_file
        node_table = BioTCM::Table.new(node_file)
        @node_table.primary_key = node_table.primary_key
        @node_table = @node_table.merge(node_table)
      end

      # Set members
      @node = @node_table.instance_variable_get(:@row_keys).clone
      @edge = @edge_table.instance_variable_get(:@row_keys).clone
    end
    # Clone the network but share the same background
    # @return [Network]
    def clone
      net = super
      net.instance_variable_set(:@node, @node.clone)
      net.instance_variable_set(:@edge, @edge.clone)
      return net
    end
    # Get a network with selected nodes and edges between them
    # @return [Network]
    def select(list)
      self.clone.select!(list)
    end
    # Leaving selected nodes and edges between them
    # @return [self]
    def select!(list)
      # Node
      (@node.keys - list).each { |k| @node.delete(k) }
      # Edge
      regexp = Regexp.new(INTERACTION_TYPES.join("|"))
      @edge.select! do |edge|
        src, tgt = edge.split(regexp)
        @node[src] && @node[tgt] ? true : false
      end
      return self
    end
    # Get a expanded network
    # @return [Network]
    def expand(step=1)
      self.clone.expand!(step)
    end
    # Expand self
    # @return [self]
    def expand!(step=1)
      step.times { self.expand } if step > 1
      all_node = @node_table.instance_variable_get(:@row_keys)
      old_node = @node
      @node = {}
      # Edge
      regexp = Regexp.new(INTERACTION_TYPES.join("|"))
      @edge_table.instance_variable_get(:@row_keys).each do |edge, edge_index|
        next if @edge[edge]
        src, tgt = edge.split(regexp)
        next unless old_node[src] || old_node[tgt]

        @edge[edge] = edge_index
        @node[src] = all_node[src] unless @node[src]
        @node[tgt] = all_node[tgt] unless @node[tgt]
      end
      return self
    end
    # Get a network without given nodes
    # @return [Network]
    def knock_down(list)
      self.clone.knock_down!(list)
    end
    # Knock given nodes down
    # @return [self]
    def knock_down!(list)
      self.select!(self.node - list)
    end
  end
end
