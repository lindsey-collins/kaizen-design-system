import { graphql, StaticQuery } from "gatsby"
import * as React from "react"
import IconTile from "./IconTile"

const styles = require("./IconGrid.scss")

type IconGridProps = {}

const IconGrid: React.SFC<IconGridProps> = props => (
  <StaticQuery
    query={graphql`
      query IconQuery {
        allFile(filter: { sourceInstanceName: { eq: "icons" } }) {
          edges {
            node {
              publicURL
              relativePath
            }
          }
        }
      }
    `}
    render={data => (
      <div>
        <div className={styles.iconGrid}>
          {data.allFile.edges.map((edge: any) => (
            <IconTile
              path={edge.node.publicURL}
              filename={edge.node.relativePath}
            />
          ))}
        </div>
      </div>
    )}
  />
)

export default IconGrid
