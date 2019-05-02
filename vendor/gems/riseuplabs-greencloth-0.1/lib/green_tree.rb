##
## GreenTree -- a nested tree used for building the outline
##
class GreenTree < Array
  attr_accessor :heading_level
  attr_accessor :name

  attr_accessor :start_index
  attr_accessor :end_index

  attr_accessor :parent
  attr_accessor :text

  def to_hash
    hash = {
      name: name,
      start_index: start_index,
      end_index: end_index,
      heading_level: heading_level,
      children: collect(&:to_hash)
    }
  end

  def self.from_hash(hash, greencloth)
    root_node = GreenTree.new(nil, hash[:name], hash[:heading_level], nil, greencloth)
    root_node.start_index = hash[:start_index]
    root_node.end_index = hash[:end_index]

    subtree_from_hash(root_node, hash[:children])
    root_node
  end

  def self.subtree_from_hash(parent_node, child_hashes)
    child_hashes.each do |hash|
      child_node = parent_node.add_child(nil, hash[:name], hash[:heading_level])
      child_node.start_index = hash[:start_index]
      child_node.end_index = hash[:end_index]

      subtree_from_hash(child_node, hash[:children])
    end
  end

  def initialize(text = nil, name = nil, heading_level = nil, parent = nil, greencloth = nil)
    tree = super()
    tree.text = text
    tree.heading_level = heading_level
    tree.name = name
    tree.parent = parent
    tree.greencloth = greencloth || (parent.greencloth if parent)
    tree
  end

  def inspect
    if leaf?
      %["#{name}(#{start_index}..#{end_index})"]
    else
      %["#{name || 'document'}(#{start_index}..#{end_index})" -> [#{map(&:inspect).join(', ')}]]
    end
  end

  def ==(other)
    name == other.name &&
      heading_level == other.heading_level &&
      parent == other.parent
  end

  alias to_s inspect
  alias leaf? empty?

  def root?
    parent.nil?
  end

  def children
    self
  end

  def add_child(text, name, heading_level)
    self << GreenTree.new(text, name, heading_level, self)
    last
  end

  # returns a list of siblings for this node (including itself)
  # in their original order
  def siblings
    # this node has no siblings since it's a root node
    return [] if root?
    # we have some siblings
    parent.children
  end

  # the sibling after this node
  def next_sibling
    # find self node among siblings
    self_index = siblings.index(self)
    # this will return the next sibling, or nil if we have no next siblings
    return siblings[self_index + 1] if self_index
  end

  # all children and parents for this node
  def genealogy
    ancestors + descendants
  end

  # parent and parents parent for this node (excluding itself)
  def ancestors
    return [] if root?
    [parent] + parent.ancestors
  end

  # children and childrens children for this node (including itself)
  def descendants
    all = [self]
    children.each { |child| all += child.descendants }
    all.compact
  end

  # returns the node after this one
  def successor
    # this node has no successor since it's a root node
    return nil if root?

    sibling = next_sibling
    if sibling
      return sibling
    else
      # we have no siblings, so try parent's successor
      return parent.successor
    end
  end

  # walks tree, looking for a node that matches
  def find(name)
    children.each do |node|
      if node.name == name
        return node
      elsif !node.leaf?
        node = node.find(name)
        return node unless node.nil?
      end
    end
    nil # not found
  end

  # get the list of all the available heading names in this tree
  # order from text top to text bottom
  def section_names
    names = []
    names << name
    children.each do |child|
      names.concat child.section_names
    end
    names.compact
  end

  def prepare_markup_indexes
    if parent
      raise GreenClothException, "GREENCLOTH ERROR: 'prepare_markup_indexes' can only be called on the root document node"
    else
      markup = greencloth.to_s.clone
      prepare_markup_start_index!(markup)
      prepare_markup_end_index!(markup)
      self.end_index = markup.size - 1
    end
  end

  # returns the markup text for this section
  def markup
    greencloth[start_index..end_index]
  end

  # returns the whole greencloth text, with this section replaced with +markup+
  # does not modify any data this node has
  def sub_markup(section_markup)
    current_markup = greencloth.to_s.clone

    markup_newlines = section_markup.scan(/[\n\r]+\Z/).last.to_s
    # should have minimum 2 newlines

    # don't apprend the trailing whitespace to the sections that
    # hit the end of the document text
    unless root? or successor.nil?
      section_markup << "\n\n" if markup_newlines.length < 2
    end

    current_markup[start_index..end_index] = section_markup
    current_markup
  end

  protected

  # others should not be able to modify this
  attr_accessor :greencloth

  # modifies markup
  # finds the location for each heading in the markup
  def prepare_markup_start_index!(markup, offset = 0)
    # recurse over children first, this way we're guaranteed
    # to find every occurance of any title text in left-to-right (or top-to-bottom in a greencloth text)
    # order
    # children have a higher offset, let's keep it separate from our own.
    child_offset = offset
    children.each do |node|
      child_offset = node.prepare_markup_start_index!(markup, child_offset)
    end

    # assume the node markup starts at the begining of the document
    # this is true for :document node
    # and is better than 'nil' start_index for nodes that can't be be found in the markup
    self.start_index = 0

    if text
      # find the first occurance of this node in the markup
      self.start_index = markup.index(markup_regexp, offset)
      if start_index.nil?
        raise GreenClothHeadingError.new(text, markup, markup_regexp)
      else
        # modify the markup, so that it will no longer match
        # the markup_regexp at this position
        markup[start_index] = "\000"
      end
    end
    start_index
  end

  def prepare_markup_end_index!(markup)
    # self and all children have start index
    # traverse the tree depth first, left-to-right (directly top-to-bottom in greencloth text layout)
    children.each do |child_node|
      child_node.prepare_markup_end_index!(markup)
      child_node_successor = child_node.successor
      if child_node_successor and child_node_successor.start_index
        child_node.end_index = child_node_successor.start_index - 1
      else
        # no successor for this child node. means this is the last node
        child_node.end_index = markup.size - 1
      end
    end
  end

  # returns a regexp that can be used to find the original markup for
  # this node in a body of greencloth text. it is a little iffy.
  # the text we have (self.text) has already been transformed by
  # greencloth (there is not a good way around this). So, we have
  # some transformed text, that we then need to match against original text.
  # yep, it is that ugly.
  def markup_regexp
    if heading_level > 2
      heading_level_regexp
    else
      Regexp.union heading_level_regexp, heading_underline_regexp
    end
  end

  protected

  def regexp_text
    @regexp_text ||=
      Regexp.escape(text).
      # look for the words - but allow special chars in between
      gsub(/\\\s/, '[\W_](.*[\W_])?').
      # remove html entities, and let them match one to several characters
      gsub(/&(\w{2,6}?|\\#[0-9A-Fa-f]{2,6});/, '.{1,3}').
      split('\n').first
  end

  def heading_underline_regexp
    underline = heading_level == 1 ? '=' : '-'
    /^
    [^\n]*#{regexp_text}[^\n]*\s*
    \n#{underline}+\s*?(\r?\n\r?\n?|$)
    /x
  end

  def heading_level_regexp
    /^
    h#{heading_level}\.\s+
    [^\n]*#{regexp_text}[^\n]*
    \s*?(\r?\n\r?\n?|$)
    /x
  end
end
