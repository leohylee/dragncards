import { useSelector } from "react-redux";
import { useCurrentSide } from "./useCurrentSide";

export const useCurrentFace = (cardId) => {
    const currentSide = useCurrentSide(cardId);
    return useSelector(state => {
        const card = state?.gameUi?.game?.cardById?.[cardId];
        if (!card) return null;

        // Handle both nested (sides.A) and flat (A) structures
        if (card.sides && typeof card.sides === 'object' && !Array.isArray(card.sides)) {
            return card.sides[currentSide];
        } else {
            return card[currentSide];
        }
    });
}