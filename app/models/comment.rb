# == Schema Information
#
# Table name: comments
#
#  id           :integer       not null, primary key
#  verse_id     :integer       
#  person_id    :integer       
#  text         :text          
#  created_at   :datetime      
#  updated_at   :datetime      
#  recipe_id    :integer       
#  news_item_id :integer       
#  song_id      :integer       
#  note_id      :integer       
#  site_id      :integer       
#  picture_id   :integer       
#

class Comment < ActiveRecord::Base
  belongs_to :person
  belongs_to :site
  
  # TODO: use polymorphism 
  belongs_to :verse
  belongs_to :recipe
  belongs_to :note
  belongs_to :picture
  
  scope_by_site_id
    
  def on
    verse || recipe || note || picture
  end
  
  def name
    "Comment on #{on ? on.name : '?'}"
  end
    
  acts_as_logger LogItem
  
  after_create :update_stream_items_on_create
  
  def update_stream_items_on_create
    find_all_associated_stream_items.each do |stream_item|
      next if stream_item.streamable_type == 'Album' and not stream_item.context['picture_ids'].include?(on.id)
      stream_item.context['comments'] ||= []
      stream_item.context['comments'] << {
        'id'         => id,
        'person_id'  => person.id,
        'text'       => text,
        'created_at' => created_at
      }
      stream_item.save!
    end
  end
  
  after_destroy :update_stream_items_on_destroy
  
  def update_stream_items_on_destroy
    find_all_associated_stream_items.each do |stream_item|
      stream_item.context['comments'] ||= []
      stream_item.context['comments'].reject! { |c| c['id'] == id }
      stream_item.save!
    end
  end
  
  def find_all_associated_stream_items
    return [] unless on
    streamable_type = on.class.name
    streamable_id   = on.id
    if streamable_type == 'Picture'
      streamable_type = 'Album'
      streamable_id   = on.album_id
    end
    StreamItem.find_all_by_streamable_type_and_streamable_id(streamable_type, streamable_id)
  end
end
