# frozen_string_literal: true

module RedmineKeycloakOidc
  class GroupSync
    class << self
      def sync(user, claims, first_login: false)
        settings = RedmineKeycloakOidc::SettingsHelper.raw_hash
        group_claim = settings['group_claim'].to_s.presence || 'realm_access.roles'
        values = extract_claim_value(claims, group_claim)
        return if values.blank?

        rules = (settings['group_mapping_rules'] || []).select { |r| r['pattern'].to_s.present? && r['group_id'].to_i.positive? }
        old_mapping = (settings['group_mapping'] || {}).transform_keys(&:to_s).transform_values(&:to_i)

        target_group_ids = if rules.any?
          values.flat_map do |claim_value|
            rules.select { |r| File.fnmatch(r['pattern'].to_s, claim_value.to_s, File::FNM_EXTGLOB) }.map { |r| r['group_id'].to_i }
          end.uniq
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
