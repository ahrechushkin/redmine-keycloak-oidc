# frozen_string_literal: true

module RedmineKeycloakOidc
  class GroupSync
    class << self
      def sync(user, claims, first_login: false)
        settings = RedmineKeycloakOidc::SettingsHelper.effective_hash
        group_claim = settings['group_claim'].to_s.presence || 'realm_access.roles'
        values = extract_claim_value(claims, group_claim)
        return if values.blank?

        rules = (settings['group_mapping_rules'] || []).select { |r| r['pattern'].to_s.present? && r['group_id'].to_i.positive? }
        rules = rules.sort_by { |r| r['priority'].to_i }
        old_mapping = (settings['group_mapping'] || {}).transform_keys(&:to_s).transform_values(&:to_i)

        target_group_ids = if rules.any?
          values.map do |claim_value|
            rule = rules.find { |r| pattern_match?(r['pattern'].to_s, claim_value.to_s) }
            rule ? rule['group_id'].to_i : nil
          end.compact.uniq
        elsif old_mapping.any?
          values.map { |v| old_mapping[v.to_s] }.compact.uniq
        else
          []
        end
        return if target_group_ids.blank?
        current_group_ids = user.group_ids

        if first_login
          (target_group_ids - current_group_ids).each do |gid|
            group = Group.find_by(id: gid)
            group&.users << user
          end
        else
          to_add = target_group_ids - current_group_ids
          to_remove = current_group_ids - target_group_ids
          to_add.each do |gid|
            group = Group.find_by(id: gid)
            group&.users << user
          end
          to_remove.each do |gid|
            group = Group.find_by(id: gid)
            group&.users&.delete(user) if group
          end
        end
      end

      def pattern_match?(pattern, value)
        return false if pattern.blank?
        if pattern.start_with?('/') && pattern.end_with?('/') && pattern.length > 2
          regex = Regexp.new(pattern[1..-2])
          !regex.match(value).nil?
        else
          File.fnmatch(pattern, value, File::FNM_EXTGLOB)
        end
      rescue RegexpError
        false
      end

      def extract_claim_value(claims, key_path)
        return nil if claims.blank? || key_path.blank?
        keys = key_path.to_s.split('.')
        obj = claims
        keys.each do |k|
          obj = obj.is_a?(Hash) ? obj[k] : nil
          break if obj.nil?
        end
        return nil if obj.nil?
        obj.is_a?(Array) ? obj : [obj]
      end
    end
  end
end
