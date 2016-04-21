# E1626
class BadgesController < ApplicationController

  def action_allowed?
    true
  end

  def new
    course_id = params[:course_id]
    @assignments = Assignment.where("course_id = ?", course_id)
    @list_badges = Array.new

    response = get_badges_created(session[:user].id)
    parsed_response = JSON.parse(response.body)
    user_data = nil

    @badgeGroups = BadgeGroup.where("course_id = ? AND is_course_level_group = ?", course_id, true)

    if response.code == '200' && !parsed_response['data'].nil?
      parsed_response['data'].each do |badge|
        @badge_info = Hash.new
        @badge_info["badge_image_url"] = badge["image_url"]
        @badge_info["badge_title"] = badge["title"]
        @badge_info["badge_id"] = badge["id"]
        if Badge.where("credly_badge_id = ?", badge["id"]).blank?
          new_badge = Badge.new
          new_badge.name = badge["title"]
          new_badge.credly_badge_id = badge["id"]
          new_badge.save!
        end
        @list_badges.push @badge_info
      end
    else
      user_data = parsed_response['meta']
    end

    # response = get_badges_created(expertiza_admin_user_id)
    # parsed_response = JSON.parse(response.body)
    #
    # if response.code == '200' && !parsed_response['data'].nil?
    #   user_data = parsed_response['data']
    #   user_data.each do |badge|
    #     @badge_info["badge_image_url"] = badge["image_url"]
    #     @badge_info["badge_title"] = badge["title"]
    #     @badge_info["badge_id"] = badge["id"]
    #     if Badge.where("credly_badge_id = ?", badge["id"]).blank?
    #       new_badge = Badge.new
    #       new_badge.name = badge["title"]
    #       new_badge.credly_badge_id = badge["id"]
    #       new_badge.save!
    #     end
    #     @list_badges.push @badge_info
    #   end
    # else
    #   user_data = parsed_response['meta']
    # end
  end

  def create
    badge_strategy = params["badge"]["badge_assignment_strategy"]
    badge_threshold = ""
    if params["badge"]["badge_assignment_threshold"].empty? || params["badge"]["badge_assignment_threshold"].nil?
      badge_threshold = params["badge"]["badge_assignment_NumBadges"]
    else
      badge_threshold = params["badge"]["badge_assignment_threshold"]
    end
    id_badge_selected = params["badge_selected"]

    assignment_id_from_form = Array.new
    params.each do |key, value|
      if key.include? "assign"
        assignment_id_from_form.push key.split('_', 2).last
      end
    end

    badge_group = BadgeGroup.new
    badge_group.strategy = badge_strategy
    badge_group.threshold = badge_threshold.to_i
    badge_group.is_course_level_group = true
    badge_group.course_id = params[:course_id].to_i
    badge_group.badge_id = id_badge_selected.to_i
    badge_group.save!

    assignment_id_from_form.each do |assgn_id|
      assignment_group = AssignmentGroup.new
      assignment_group.badge_group_id = badge_group.id
      assignment_group.assignment_id = assgn_id.to_i
      assignment_group.save!
    end

    redirect_to :controller => 'tree_display', :action => 'list'
  end

  def show
  end

  def index
  end

  def edit
    @assignments_list = AssignmentGroup.where('badge_group_id = ?', params['badge_group_id'])
    @badgeGroup = BadgeGroup.find_by_badge_id(params['badge_group_id'])

    print j
    i =0
  end

  def configuration
    @badge_groups = BadgeGroup.where("course_id = ? and is_course_level_group = TRUE", params[:course_id])
  end

  private

  def get_badges_created(user_id)
    uri = URI.parse("https://api.credly.com")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    token = User.select('credly_accesstoken').where("id = ?", user_id)
    request = Net::HTTP::Get.new("/v1.1/me/badges/created?order_direction=ASC&access_token=" + token[0].credly_accesstoken)
    request["X-Api-Key"] = "f14c0138c043c3159420f297276eab61"
    request["X-Api-Secret"] = "6qmzTxOQZJfF5K1ExH80K+umX9gfU5lmtswycO9TycswGbKEIPwuoXxcIohF4d6go0FeLMRv9uV+MD0jmeQsHBDaTNKa+blumqcd+cfK1y5lqTbLiLZsxdue9vth3Lh9U6Juy1rvy2VGYo8EOqh46PMjOmmOTUIZan9vvaf8Z0I="
    response = http.request(request)
    response
  end

end
