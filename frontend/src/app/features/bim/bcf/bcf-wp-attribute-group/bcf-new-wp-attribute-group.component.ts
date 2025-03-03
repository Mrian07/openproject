import { ChangeDetectionStrategy, Component } from '@angular/core';
import { BcfWpAttributeGroupComponent } from 'core-app/features/bim/bcf/bcf-wp-attribute-group/bcf-wp-attribute-group.component';
import { switchMap, take } from 'rxjs/operators';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { forkJoin } from 'rxjs';
import { BcfViewpointInterface } from 'core-app/features/bim/bcf/api/viewpoints/bcf-viewpoint.interface';
import { BcfViewpointItem } from 'core-app/features/bim/bcf/api/viewpoints/bcf-viewpoint-item.interface';
import isNewResource from 'core-app/features/hal/helpers/is-new-resource';

@Component({
  templateUrl: './bcf-wp-attribute-group.component.html',
  styleUrls: ['./bcf-wp-attribute-group.component.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BcfNewWpAttributeGroupComponent extends BcfWpAttributeGroupComponent {
  galleryViewpoints:BcfViewpointItem[] = [];

  ngAfterViewInit():void {
    if (this.viewerVisible) {
      super.ngAfterViewInit();

      // Save any leftover viewpoints when saving the work package
      if (isNewResource(this.workPackage)) {
        this.observeCreation();
      }
    }
  }

  // Because this is a new WorkPackage, in order to save the
  // viewpoints on it we need to:
  // - Wait until the WorkPackage is created
  // - Create the BCFTopic on it to save the viewpoints
  private observeCreation() {
    this.wpCreate
      .onNewWorkPackage()
      .pipe(
        this.untilDestroyed(),
        take(1),
        switchMap((wp:WorkPackageResource) => this.viewpointsService.setBcfTopic$(wp), (wp) => wp),
        switchMap((wp:WorkPackageResource) => {
          this.workPackage = wp;
          const observables = this.galleryViewpoints
            .filter((viewPointItem) => !viewPointItem.href && viewPointItem.viewpoint)
            .map((viewPointItem) => this.viewpointsService.saveViewpoint$(this.workPackage, viewPointItem.viewpoint));

          return forkJoin(observables);
        }),
      )
      .subscribe((viewpoints:BcfViewpointInterface[]) => {
        this.showIndex = this.galleryViewpoints.length - 1;
      });
  }

  // Disable show viewpoint functionality
  showViewpoint(workPackage:WorkPackageResource, index:number) {

  }

  deleteViewpoint(workPackage:WorkPackageResource, index:number) {
    this.galleryViewpoints = this.galleryViewpoints.filter((_, i) => i !== index);

    this.setViewpointsOnGallery(this.galleryViewpoints);
  }

  saveViewpoint() {
    this.viewerBridge
      .getViewpoint$()
      .subscribe((viewpoint) => {
        const newViewpoint = {
          snapshotURL: viewpoint.snapshot.snapshot_data,
          viewpoint,
        };

        this.galleryViewpoints = [
          ...this.galleryViewpoints,
          newViewpoint,
        ];

        this.setViewpointsOnGallery(this.galleryViewpoints);

        // Select the last created viewpoint and show it
        this.showIndex = this.galleryViewpoints.length - 1;
        this.selectViewpointInGallery();
      });
  }

  shouldShowGroup() {
    return this.createAllowed && this.viewerVisible;
  }

  protected actions() {
    // Show only delete button
    return super
      .actions()
      .filter((el) => el.icon === 'icon-delete');
  }
}
