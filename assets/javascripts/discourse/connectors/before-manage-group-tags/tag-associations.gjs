/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { i18n } from "discourse-i18n";

@tagName("div")
@classNames("before-manage-group-tags-outlet", "tag-associations")
export default class TagAssociations extends Component {
  <template>
    <div class="control-group">
      <label class="control-label">{{i18n
          "group_tag_associations.title"
        }}</label>
      <div>{{i18n "group_tag_associations.description"}}</div>
    </div>

    <div class="control-group">
      <TagChooser
        @tags={{this.model.associated_tags}}
        @allowCreate={{false}}
        @everyTag={{true}}
      />
    </div>
  </template>
}
