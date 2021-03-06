class LeaderboardController < ApplicationController
  before_filter :authorize

  def action_allowed?
    true
  end

  # Allows to view leaderBoard - sorted on max number of badges received by a course participant
  # E1626
  def index
    if current_user
      @instructor_query = LeaderboardHelper.user_is_instructor?(current_user.id)

      if @instructor_query
        @course_list = LeaderboardHelper.instructor_courses(current_user.id)
      else
        @course_list = LeaderboardHelper.student_in_which_courses(current_user.id)
      end
      @course_info = Leaderboard.getCourseInfo(@course_list)
    end
  end

  def view
    ##Get Course participants
    #@instructor = User.find_by_id(params[:user_id])
    @course = Course.find_by_id(params[:course_id])
    @instructor = Instructor.find_by_id(@course.instructor_id)
    @participants = Participant.where('parent_id = ?', params[:course_id]).pluck(:user_id)
    @students = User.where('id in (?) and role_id = ?', @participants, 1)
    @assignments = Assignment.where('course_id = ?', params[:course_id])

    #get assignment stages
    assignment_stage = LeaderboardHelper.get_stage_assignments(@assignments, @students)

    @student_badges = Hash[@students.pluck(:id).map { |x| [x, nil] }]
    @track_badge_users = Array.new

    #GetBadgeGroups
    @badge_groups = BadgeGroup.where('course_id = ?', params[:course_id])
    @badge_groups.each do |badge_group|

      if badge_group.badges_awarded == false

        @assignment_groups = AssignmentGroup.where('badge_group_id = ?', badge_group.id)

        assignment_id = @assignment_groups.pluck(:assignment_id)
        assignment_status = 1

        assignment_id.each do |a|
          if assignment_stage[a] != 'Finished'
            assignment_status = 0
          end
        end

        if assignment_status == 1
          participant_scores = Hash.new
          participant_scores = LeaderboardHelper.get_participant_scores(participant_scores, @assignment_groups)
          #Average Score Calculation
          participant_scores.each { |k, v| participant_scores[k] = v/@assignment_groups.length }
          sorted_scores = Hash[participant_scores.sort_by { |k, v| v }.reverse!]

          if @assignment_groups.count == 1
            final_users = LeaderboardHelper.get_eligible_users_for_badge badge_group, sorted_scores, @assignment_groups[0].assignment_id
          else
            if badge_group.strategy == 'Top Scores'
              final_users = LeaderboardHelper.get_users_top_scores_team_of_one sorted_scores, badge_group.threshold
            elsif badge_group.strategy == 'Score Threshold'
              final_users = LeaderboardHelper.get_users_threshold_team_of_one sorted_scores, badge_group.threshold
            end
          end


          final_users.each do |u|
            if @assignment_groups.count == 1
              @track_badge_users = LeaderboardHelper.assign_badge_user badge_group.badge_id, u, 1, @assignment_groups[0].assignment_id, params[:course_id], @track_badge_users, @course
            elsif @assignment_groups.count > 1
              @track_badge_users = LeaderboardHelper.assign_badge_user badge_group.badge_id, u, 0, nil, params[:course_id], @track_badge_users, @course
            end

            if @student_badges[u] == nil
              badge_array = Array.new
              badge_array.push(badge_group.badge_id)
              @student_badges[u] = badge_array
            else
              badge_array = @student_badges[u]
              badge_array.push(badge_group.badge_id)
              @student_badges[u] = badge_array
            end
          end
          badge_group.badges_awarded = true
          badge_group.save!
        end
      else
        if badge_group.is_course_level_group == false
          @assignment_groups = AssignmentGroup.where('badge_group_id = ?', badge_group.id)
          students_with_badges = BadgeUser.where('assignment_id = ? and course_id = ? and badge_id = ?', @assignment_groups[0].assignment_id, params[:course_id], badge_group.badge_id)
          @track_badge_users, @student_badges = LeaderboardHelper.get_students_badges(badge_group, students_with_badges, @track_badge_users, @student_badges)
        else
          students_with_badges = BadgeUser.where('is_course_badge = ? and course_id = ? and badge_id = ?', 1, params[:course_id], badge_group.badge_id)
          @track_badge_users, @student_badges = LeaderboardHelper.get_students_badges(badge_group, students_with_badges, @track_badge_users, @student_badges)
        end
      end
    end

    #add badges awarded by instructor manually
    @track_badge_users, @student_badges = LeaderboardHelper.instructor_added_badges(@track_badge_users, @student_badges, params[:course_id])

    #get badge URLs
    @badgeURL, @badge_names = LeaderboardHelper.get_badges_info @course
    @student_badges.delete_if { |k, v| v.nil? }
    @sorted_student_badges = Hash[@student_badges.sort_by { |k, v| v.size }.reverse]
    @badgeURL
  end

end
